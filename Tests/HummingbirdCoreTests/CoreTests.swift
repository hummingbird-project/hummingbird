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

import Atomics
import HummingbirdCore
@testable import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
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

    func testConnect() async throws {
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: HelloResponder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let response = try await client.get("/")
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
    }

    func testError() async throws {
        struct ErrorResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                onComplete(.failure(HBHTTPError(.unauthorized)))
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: ErrorResponder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let response = try await client.get("/")
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers["content-length"].first, "0")
        }
    }

    func testConsumeBody() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testConsumeAllBody() async throws {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let size = ManagedAtomic(0)
                let allocator = context.channel.allocator
                let eventLoop = context.eventLoop
                request.body.stream!.consumeAll(on: eventLoop) { buffer in
                    size.wrappingIncrement(by: buffer.readableBytes, ordering: .relaxed)
                    return eventLoop.makeSucceededFuture(())
                }
                .whenComplete { result in
                    switch result {
                    case .success:
                        let response = HBHTTPResponse(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok),
                            body: .byteBuffer(allocator.buffer(integer: size.load(ordering: .relaxed)))
                        )
                        onComplete(.success(response))
                    case .failure(let error):
                        onComplete(.failure(error))
                    }
                }
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 450_000)
            let response = try await client.post("/", body: buffer)
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readInteger(), buffer.readableBytes)
        }
    }

    func testConsumeBodyInTask() async throws {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBody() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBody2() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testAsyncStreamBody() async throws {
        struct Responder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                let streamer = HBByteBufferStreamer(eventLoop: context.eventLoop, maxSize: 1024 * 2048, maxStreamingBufferSize: 32 * 1024)
                Task {
                    do {
                        for try await buffer in request.body.stream!.sequence {
                            try await streamer.feed(buffer: buffer).get()
                        }
                        streamer.feed(.end)
                    } catch {
                        streamer.feed(.error(error))
                    }
                }
                let response = HBHTTPResponse(
                    head: .init(version: .init(major: 1, minor: 1), status: .ok),
                    body: .stream(streamer)
                )
                onComplete(.success(response))
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBodySlowProcess() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxStreamingBufferSize: 256 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBodySlowStream() async throws {
        /// channel handler that delays the sending of data
        class SlowInputChannelHandler: ChannelOutboundHandler, RemovableChannelHandler {
            public typealias OutboundIn = Never
            public typealias OutboundOut = HTTPServerResponsePart

            func read(context: ChannelHandlerContext) {
                let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
                context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 25..<200))) {
                    loopBoundContext.value.read()
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: Responder(),
            additionalChannelHandlers: [SlowInputChannelHandler()],
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testChannelHandlerErrorPropagation() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: Responder(),
            additionalChannelHandlers: [CreateErrorHandler()],
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 32)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .insufficientStorage)
        }
    }

    func testStreamedRequestDrop() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: Responder(),
            additionalChannelHandlers: [BreakupHTTPBodyChannelHandler()],
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 16384)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testMaxStreamedUploadSize() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxUploadSize: 64 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 320_000)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .payloadTooLarge)
        }
    }

    func testMaxUploadSize() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxUploadSize: 64 * 1024),
            responder: Responder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            let buffer = self.randomBuffer(size: 320_000)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .payloadTooLarge)
        }
    }

    /// test a request is finished with before the next one starts to be processed
    func testHTTPPipelining() async throws {
        struct WaitResponder: HBHTTPResponder {
            func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
                guard let wait = request.head.headers["wait"].first.map({ Int64($0) }) ?? nil else {
                    onComplete(.failure(HBHTTPError(.badRequest)))
                    return
                }
                let channel = context.channel
                context.eventLoop.scheduleTask(in: .milliseconds(wait)) {
                    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
                    let responseBody = channel.allocator.buffer(string: "\(wait)")
                    let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
                    onComplete(.success(response))
                }
            }
        }
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0), maxUploadSize: 64 * 1024),
            responder: WaitResponder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            try await withThrowingTaskGroup(of: Void.self) { group in
                let waitTimes: [Int] = (0..<16).map { _ in Int.random(in: 0..<50) }
                for time in waitTimes {
                    group.addTask {
                        let headers: HTTPHeaders = ["wait": String(describing: time), "connection": "keep-alive"]
                        let response = try await client.get("/", headers: headers)
                        XCTAssertEqual(response.body.map { String(buffer: $0) }, "\(time)")
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    /// test server closes connection if "connection" header is set to "close"
    func testConnectionClose() async throws {
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: HelloResponder(),
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            try await withTimeout(.seconds(5)) {
                _ = try await client.get("/", headers: ["connection": "close"])
                let channel = try await client.channelPromise.futureResult.get()
                try await channel.closeFuture.get()
            }
        }
    }

    func testBodyDescription() {
        XCTAssertEqual(HBRequestBody.byteBuffer(nil).description, "empty")
        XCTAssertEqual(HBRequestBody.byteBuffer(self.randomBuffer(size: 64)).description, "64 bytes")
        XCTAssertEqual(HBRequestBody.byteBuffer(.init(string: "Test String")).description, "\"Test String\"")
    }

    func testReadIdleHandler() async throws {
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
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: HelloResponder(),
            additionalChannelHandlers: [HTTPServerIncompleteRequest(), IdleStateHandler(readTimeout: .seconds(1))],
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            try await withTimeout(.seconds(5)) {
                do {
                    _ = try await client.get("/", headers: ["connection": "keep-alive"])
                    XCTFail("Should not get here")
                } catch HBXCTClient.Error.connectionClosing {
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testWriteIdleTimeout() async throws {
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: HelloResponder(),
            additionalChannelHandlers: [IdleStateHandler(writeTimeout: .seconds(1))],
            logger: Logger(label: "HB")
        )
        try await testServer(server) { client in
            try await withTimeout(.seconds(5)) {
                _ = try await client.get("/", headers: ["connection": "keep-alive"])
                let channel = try await client.channelPromise.futureResult.get()
                try await channel.closeFuture.get()
            }
        }
    }

    func testServerAsService() async throws {
        final class Barrier: @unchecked Sendable {
            let cont: AsyncStream<Void>.Continuation
            let stream: AsyncStream<Void>

            init() {
                var cont: AsyncStream<Void>.Continuation!
                self.stream = AsyncStream<Void> { cont = $0 }
                self.cont = cont
            }

            func wait() async {
                await self.stream.first { _ in true }
            }

            func signal() {
                self.cont.yield()
            }
        }

        let barrier = Barrier()
        var logger = Logger(label: "HB")
        logger.logLevel = .trace
        let server = HBHTTPServer(
            group: Self.eventLoopGroup,
            configuration: .init(address: .hostname(port: 0)),
            responder: HelloResponder(),
            onServerRunning: { barrier.signal() },
            logger: logger
        )
        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = await ServiceGroup(
                services: [server],
                configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
                logger: server.logger
            )
            group.addTask {
                try await serviceGroup.run()
            }
            await barrier.wait()
            let client = await HBXCTClient(
                host: "localhost",
                port: server.port!,
                configuration: .init(timeout: .seconds(2)),
                eventLoopGroupProvider: .createNew
            )
            client.connect()
            group.addTask {
                _ = try await client.get("/")
            }
            try await group.next()
            await serviceGroup.triggerGracefulShutdown()
            try await client.shutdown()
        }
    }
}
