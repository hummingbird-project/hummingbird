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

import HummingbirdCore
@testable import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP1
import NIOPosix
import NIOTransportServices
#if canImport(Network)
import Network
import NIOTransportServices
#endif
import XCTest

class HummingBirdCoreTests: XCTestCase {
    static var eventLoopGroup: EventLoopGroup!

    override class func setUp() {
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
    }

    override class func tearDown() {
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        XCTAssertNoThrow(try server.start(responder: ErrorResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers["content-length"].first, "0")
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(maxSize: .max, on: context.eventLoop).whenComplete { result in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 450_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readInteger(), buffer.readableBytes)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testConsumeBodyInTask() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let eventLoop = context.eventLoop
                Task {
                    do {
                        let buffer = try await request.body.consumeBody(maxSize: .max)
                        guard let buffer = buffer else {
                            onComplete(.failure(HBHTTPError(.badRequest)))
                            return
                        }
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(buffer)
                        )
                        onComplete(.success(response))

                    } catch {
                        onComplete(.failure(error))
                    }
                }
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBody() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let eventLoop = context.eventLoop
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream!.consume(on: eventLoop).map { output in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBody2() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let streamer = HBByteBufferStreamer(eventLoop: context.eventLoop, maxSize: 2048 * 1024, maxStreamingBufferSize: 32 * 1024)
                request.body.stream?.consumeAll(on: context.eventLoop) { buffer in
                    return streamer.feed(buffer: buffer)
                }
                .flatMapErrorThrowing { error in
                    streamer.feed(.error(error))
                    throw error
                }
                .whenComplete { _ in
                    streamer.feed(.end)
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: .stream(streamer)
                )
                return onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamBodySlowProcess() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let eventLoop = context.eventLoop
                let body: HBResponseBody = .streamCallback { _ in
                    return request.body.stream!.consume(on: eventLoop).flatMap { output in
                        switch output {
                        case .byteBuffer(let buffer):
                            // delay processing of buffer
                            return eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 0..<200))) { .byteBuffer(buffer) }.futureResult
                        case .end:
                            return eventLoop.makeSucceededFuture(.end)
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(
            host: "localhost",
            port: server.port!,
            configuration: .init(timeout: .seconds(120)),
            eventLoopGroupProvider: .createNew
        )
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
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
                request.body.consumeBody(maxSize: .max, on: context.eventLoop).whenComplete { result in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        server.addChannelHandler(SlowInputChannelHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(
            host: "localhost",
            port: server.port!,
            configuration: .init(timeout: .seconds(120)),
            eventLoopGroupProvider: .createNew
        )
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 1_140_000)
        let future = client.post("/", body: buffer)
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        server.addChannelHandler(CreateErrorHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 32)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .insufficientStorage)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testStreamedRequestDrop() {
        /// Embedded channels pass all the data down immediately. This is not a real world situation so this handler
        /// can be used to fake TCP/IP data packets coming in arbitrary sizes (well at least for the HTTP body)
        class BreakupHTTPBodyChannelHandler: ChannelInboundHandler, RemovableChannelHandler {
            typealias InboundIn = HTTPServerRequestPart
            typealias InboundOut = HTTPServerRequestPart

            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                let part = unwrapInboundIn(data)

                switch part {
                case .head, .end:
                    context.fireChannelRead(data)
                case .body(var buffer):
                    while buffer.readableBytes > 0 {
                        let size = min(Int.random(in: 16...8192), buffer.readableBytes)
                        let slice = buffer.readSlice(length: size)!
                        context.fireChannelRead(self.wrapInboundOut(.body(slice)))
                    }
                }
            }
        }
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                XCTAssertNotNil(request.body.stream)
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .accepted),
                    body: .empty
                )
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        server.addChannelHandler(BreakupHTTPBodyChannelHandler())
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 16384)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .accepted)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testMaxStreamedUploadSize() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(maxSize: .max, on: context.eventLoop).whenComplete { result in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxUploadSize: 64 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 320_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .payloadTooLarge)
            }
        XCTAssertNoThrow(try future.wait())
    }

    func testMaxUploadSize() {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                request.body.consumeBody(maxSize: 64 * 1024, on: context.eventLoop).whenComplete { result in
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0), maxUploadSize: 64 * 1024))
        XCTAssertNoThrow(try server.start(responder: Responder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let buffer = self.randomBuffer(size: 320_000)
        let future = client.post("/", body: buffer)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .payloadTooLarge)
            }
        XCTAssertNoThrow(try future.wait())
    }

    /// test a request is finished with before the next one starts to be processed
    func testHTTPPipelining() throws {
        struct WaitResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                guard let wait = request.head.headers["wait"].first.map({ Int64($0) }) ?? nil else {
                    onComplete(.failure(HBHTTPError(.badRequest)))
                    return
                }
                context.eventLoop.scheduleTask(in: .milliseconds(wait)) {
                    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                    let responseBody = context.channel.allocator.buffer(string: "\(wait)")
                    let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                    onComplete(.success(response))
                }
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(
                address: .hostname(port: 0),
                withPipeliningAssistance: true // this defaults to true
            )
        )
        XCTAssertNoThrow(try server.start(responder: WaitResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let waitTimes: [Int] = (0..<16).map { _ in Int.random(in: 0..<500) }
        let futures: [EventLoopFuture<Void>] = waitTimes.map { time in
            return client.get("/", headers: ["wait": String(describing: time), "connection": "keep-alive"])
                .map { response in
                    XCTAssertEqual(response.body.map { String(buffer: $0) }, "\(time)")
                }
        }
        XCTAssertNoThrow(try EventLoopFuture.andAllSucceed(futures, on: server.eventLoopGroup.next()).wait())
    }

    /// test server closes connection if "connection" header is set to "close"
    func testConnectionClose() throws {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let responseBody = context.channel.allocator.buffer(string: "Hello")
                let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let timeoutPromise = Self.eventLoopGroup.next().makeTimeoutPromise(of: Void.self, timeout: .seconds(5))
        _ = try client.get("/", headers: ["connection": "close"]).wait()
        client.channelPromise.futureResult.whenSuccess { channel in
            channel.closeFuture.whenSuccess { _ in
                timeoutPromise.succeed(())
            }
        }
        XCTAssertNoThrow(try timeoutPromise.futureResult.wait())
    }

    /// Test we can run with an embedded channel. HummingbirdXCT uses this quite a lot
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
        let server = HBHTTPServer(group: Self.eventLoopGroup, configuration: .init(address: .hostname(port: 0)))

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

    func testBodyDescription() {
        XCTAssertEqual(HBRequestBody.byteBuffer(nil).description, "empty")
        XCTAssertEqual(HBRequestBody.byteBuffer(self.randomBuffer(size: 64)).description, "64 bytes")
        XCTAssertEqual(HBRequestBody.byteBuffer(.init(string: "Test String")).description, "\"Test String\"")
    }

    func testReadIdleHandler() {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let response = HBHTTPResponse(head: responseHead, body: .empty)
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), idleTimeoutConfiguration: .init(readTimeout: .seconds(1)))
        )
        // Fake an incomplete request by adding a handler that never passes on the `.end` HTTP part
        server.addChannelHandler(HTTPServerIncompleteRequest())
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        _ = client.get("/", headers: ["connection": "keep-alive"])
        let timeoutPromise = Self.eventLoopGroup.next().makeTimeoutPromise(of: Void.self, timeout: .seconds(5))
        client.channelPromise.futureResult.whenSuccess { channel in
            channel.closeFuture.whenSuccess { _ in
                timeoutPromise.succeed(())
            }
        }
        XCTAssertNoThrow(try timeoutPromise.futureResult.wait())
    }

    func testWriteIdleTimeout() {
        struct HelloResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                let response = HBHTTPResponse(head: responseHead, body: .empty)
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), idleTimeoutConfiguration: .init(writeTimeout: .seconds(1)))
        )
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(host: "localhost", port: server.port!, eventLoopGroupProvider: .createNew)
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        _ = client.get("/", headers: ["connection": "keep-alive"])
        let timeoutPromise = Self.eventLoopGroup.next().makeTimeoutPromise(of: Void.self, timeout: .seconds(5))
        client.channelPromise.futureResult.whenSuccess { channel in
            channel.closeFuture.whenSuccess { _ in
                timeoutPromise.succeed(())
            }
        }
        XCTAssertNoThrow(try timeoutPromise.futureResult.wait())
    }
}

/// Channel Handler for serializing request header and data
final class HTTPServerIncompleteRequest: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        switch part {
        case .end:
            break
        default:
            context.fireChannelRead(data)
        }
    }
}
