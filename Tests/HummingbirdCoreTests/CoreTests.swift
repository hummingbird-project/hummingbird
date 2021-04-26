//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncHTTPClient
import HummingbirdCore
import Logging
import NIO
import NIOHTTP1
import NIOTransportServices
#if canImport(Network)
import Network
import NIOTransportServices
#endif
import XCTest

class HummingBirdCoreTests: XCTestCase {
    static var eventLoopGroup: EventLoopGroup!
    static var httpClient: HTTPClient!

    override class func setUp() {
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
    }

    override class func tearDown() {
        XCTAssertNoThrow(try self.httpClient.syncShutdown())
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testConnect() {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let responseBody = context.channel.allocator.buffer(string: "Hello")
                let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/"
        )
        let future = Self.httpClient.execute(request: request).flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testError() {
        struct ErrorResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                onComplete(.failure(HBHTTPError(.unauthorized)))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        XCTAssertNoThrow(try server.start(responder: ErrorResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/"
        )
        let future = Self.httpClient.execute(request: request).flatMapThrowing { response in
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers["content-length"].first, "0")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(on: context.eventLoop).whenComplete { result in
                    switch result {
                    case .success(let buffer):
                        guard let buffer = buffer else {
                            onComplete(.failure(HBHTTPError(.badRequest)))
                            return
                        }
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(buffer)
                        )
                        onComplete(.success(response))
                    case .failure(let error):
                        onComplete(.failure(error))
                    }
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeAllBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                var size = 0
                request.body.stream!.consumeAll(on: context.eventLoop) { buffer in
                    size += buffer.readableBytes
                    return context.eventLoop.makeSucceededFuture(())
                }
                .whenComplete { result in
                    switch result {
                    case .success:
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(context.channel.allocator.buffer(integer: size))
                        )
                        onComplete(.success(response))
                    case .failure(let error):
                        onComplete(.failure(error))
                    }
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 450_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readInteger(), buffer.readableBytes)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream!.consume(on: context.eventLoop).map { output in
                        switch output {
                        case .byteBuffer(let buffer):
                            return .byteBuffer(buffer)
                        case .end:
                            return .end
                        }
                    }
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: body
                )
                return onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBodySlowProcess() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream!.consume(on: context.eventLoop).flatMap { output in
                        switch output {
                        case .byteBuffer(let buffer):
                            // delay processing of buffer
                            return context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 0..<200))) { .byteBuffer(buffer) }.futureResult
                        case .end:
                            return context.eventLoop.makeSucceededFuture(.end)
                        }
                    }
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: body
                )
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBodySlowStream() {
        /// channel handler that delays the sending of data
        class SlowInputChannelHandler: ChannelOutboundHandler, RemovableChannelHandler {
            public typealias OutboundIn = Never
            public typealias OutboundOut = HTTPServerResponsePart

            func read(context: ChannelHandlerContext) {
                context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 25..<200))) {
                    context.read()
                }
            }
        }
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(on: context.eventLoop).whenComplete { result in
                    let result = result.flatMap { buffer -> Result<HBHTTPResponse, Error> in
                        guard let buffer = buffer else {
                            return .failure(HBHTTPError(.badRequest))
                        }
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(buffer)
                        )
                        return .success(response)
                    }
                    onComplete(result)
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        server.addChannelHandler(SlowInputChannelHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testChannelHandlerErrorPropagation() {
        class CreateErrorHandler: ChannelInboundHandler, RemovableChannelHandler {
            typealias InboundIn = HTTPServerRequestPart

            var seen: Bool = false
            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                if case .body = self.unwrapInboundIn(data) {
                    context.fireErrorCaught(HBHTTPError(.insufficientStorage))
                }
                context.fireChannelRead(data)
            }
        }
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .accepted),
                    body: .empty
                )
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))
        server.addChannelHandler(CreateErrorHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 32)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .insufficientStorage)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testMaxUploadSize() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(on: context.eventLoop).whenComplete { result in
                    let result = result.flatMap { buffer -> Result<HBHTTPResponse, Error> in
                        guard let buffer = buffer else {
                            return .failure(HBHTTPError(.badRequest))
                        }
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(buffer)
                        )
                        return .success(response)
                    }
                    onComplete(result)
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080), maxUploadSize: 64 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let buffer = self.randomBuffer(size: 320_000)
        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/",
            body: .byteBuffer(buffer)
        )
        let future = Self.httpClient.execute(request: request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .payloadTooLarge)
            }
        XCTAssertNoThrow(try future.wait())
    }

    #if canImport(Network)
    @available(macOS 10.14, iOS 12, tvOS 12, *)
    func testNIOTransportServices() {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let responseBody = context.channel.allocator.buffer(string: "Hello")
                let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                onComplete(.success(response))
            }
        }
        let eventLoopGroup = NIOTSEventLoopGroup()
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 8081)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let request = try! HTTPClient.Request(
            url: "http://localhost:\(server.configuration.address.port!)/"
        )
        let future = Self.httpClient.execute(request: request).flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
    }
    #endif

    func testEmbeddedChannel() {
        enum HTTPError: Error {
            case noHead
            case illegalBody
            case noEnd
        }
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let responseBody = context.channel.allocator.buffer(string: "Hello")
                let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 8080)))

        do {
            let channel = EmbeddedChannel()
            try channel.pipeline.addHandlers(
                server.getChildChannelHandlers(responder: HelloResponder())
            ).wait()

            // write request
            let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: "/", headers: [:])
            try channel.writeInbound(HTTPServerRequestPart.head(requestHead))
            try channel.writeInbound(HTTPServerRequestPart.end(nil))

            // flush
            channel.flush()

            // read response
            guard case .head = try channel.readOutbound(as: HTTPServerResponsePart.self) else { throw HTTPError.noHead }
            var next = try channel.readOutbound(as: HTTPServerResponsePart.self)
            var buffer = channel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw HTTPError.illegalBody }
                buffer.writeBuffer(&b)
                next = try channel.readOutbound(as: HTTPServerResponsePart.self)
            }
            guard case .end = next else { throw HTTPError.noEnd }
        } catch {
            XCTFail("\(error)")
        }
    }
}
