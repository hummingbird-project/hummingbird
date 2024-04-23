//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncAlgorithms
import Atomics
import HTTPTypes
import HummingbirdCore
import HummingbirdTesting
import Logging
import NIOCore
import NIOHTTPTypes
import NIOPosix
import ServiceLifecycle
import XCTest

class HummingBirdCoreTests: XCTestCase {
    static let eventLoopGroup: EventLoopGroup = {
        #if os(iOS)
        NIOTSEventLoopGroup.singleton
        #else
        MultiThreadedEventLoopGroup.singleton
        #endif
    }()

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testConnect() async throws {
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .http1(),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let response = try await client.get("/")
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
    }

    func testMultipleRequests() async throws {
        try await testServer(
            responder: helloResponder,
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            for _ in 0..<10 {
                let response = try await client.post("/", body: ByteBuffer(string: "Hello"))
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
            }
        }
    }

    func testError() async throws {
        try await testServer(
            responder: { _, _ in throw HTTPError(.unauthorized) },
            httpChannelSetup: .http1(),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let response = try await client.get("/")
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers[.contentLength], "0")
        }
    }

    func testConsumeBody() async throws {
        try await testServer(
            responder: { request, _ in
                let buffer = try await request.body.collect(upTo: .max)
                return Response(status: .ok, body: .init(byteBuffer: buffer))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testWriteBody() async throws {
        try await testServer(
            responder: { _, _ in
                let buffer = self.randomBuffer(size: 1_140_000)
                return Response(status: .ok, body: .init(byteBuffer: buffer))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let response = try await client.get("/")
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readableBytes, 1_140_000)
        }
    }

    func testStreamBody() async throws {
        try await testServer(
            responder: { request, _ in
                return Response(status: .ok, body: .init(asyncSequence: request.body))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBodyWriteSlow() async throws {
        try await testServer(
            responder: { request, _ in
                return Response(status: .ok, body: .init(asyncSequence: request.body.delayed()))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
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
            public typealias OutboundOut = HTTPResponsePart

            func read(context: ChannelHandlerContext) {
                let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
                context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 5..<50))) {
                    loopBoundContext.value.read()
                }
            }
        }
        try await testServer(
            responder: { request, _ in
                return Response(status: .ok, body: .init(asyncSequence: request.body.delayed()))
            },
            httpChannelSetup: .http1(additionalChannelHandlers: [SlowInputChannelHandler()]),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testTrailerHeaders() async throws {
        try await testServer(
            responder: { _, _ in .init(status: .ok, body: .withTrailingHeaders { _ in return [.contentType: "text"] }) },
            httpChannelSetup: .http1(),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let response = try await client.get("/")
            XCTAssertEqual(response.trailerHeaders?[.contentType], "text")
        }
    }

    func testChannelHandlerErrorPropagation() async throws {
        class CreateErrorHandler: ChannelInboundHandler, RemovableChannelHandler {
            typealias InboundIn = HTTPRequestPart

            var seen: Bool = false
            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                if case .body = self.unwrapInboundIn(data) {
                    context.fireErrorCaught(HTTPError(.unavailableForLegalReasons))
                }
                context.fireChannelRead(data)
            }
        }
        try await testServer(
            responder: { request, _ in
                _ = try await request.body.collect(upTo: .max)
                return Response(status: .ok)
            },
            httpChannelSetup: .http1(additionalChannelHandlers: [CreateErrorHandler()]),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let buffer = self.randomBuffer(size: 32)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .unavailableForLegalReasons)
        }
    }

    func testDropRequestBody() async throws {
        try await testServer(
            responder: { _, _ in
                // ignore request body
                return Response(status: .accepted)
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let buffer = self.randomBuffer(size: 16384)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .accepted)
            let response2 = try await client.post("/", body: buffer)
            XCTAssertEqual(response2.status, .accepted)
        }
    }

    /// test server closes connection if "connection" header is set to "close"
    func testConnectionClose() async throws {
        try await testServer(
            responder: helloResponder,
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            try await withTimeout(.seconds(5)) {
                _ = try await client.get("/", headers: [.connection: "close"])
                let channel = try await client.channelPromise.futureResult.get()
                try await channel.closeFuture.get()
            }
        }
    }

    func testReadIdleHandler() async throws {
        /// Channel Handler for serializing request header and data
        final class HTTPServerIncompleteRequest: ChannelInboundHandler, RemovableChannelHandler {
            typealias InboundIn = HTTPRequestPart
            typealias InboundOut = HTTPRequestPart

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
        try await testServer(
            responder: { request, _ in
                _ = try await request.body.collect(upTo: .max)
                return .init(status: .ok)
            },
            httpChannelSetup: .http1(additionalChannelHandlers: [HTTPServerIncompleteRequest(), IdleStateHandler(readTimeout: .seconds(1))]),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            try await withTimeout(.seconds(5)) {
                do {
                    _ = try await client.get("/", headers: [.connection: "keep-alive"])
                    XCTFail("Should not get here")
                } catch TestClient.Error.connectionClosing {
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testWriteIdleTimeout() async throws {
        try await testServer(
            responder: { request, _ in
                _ = try await request.body.collect(upTo: .max)
                return .init(status: .ok)
            },
            httpChannelSetup: .http1(additionalChannelHandlers: [IdleStateHandler(writeTimeout: .seconds(1))]),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            try await withTimeout(.seconds(5)) {
                _ = try await client.get("/", headers: [.connection: "keep-alive"])
                let channel = try await client.channelPromise.futureResult.get()
                try await channel.closeFuture.get()
            }
        }
    }

    func testChildChannelGracefulShutdown() async throws {
        let handlerPromise = Promise<Void>()

        let childChannel = try HTTPChannelBuilder.http1().build { request, _ in
            await handlerPromise.complete(())
            try await Task.sleep(for: .milliseconds(500))
            return Response(status: .ok, body: .init(asyncSequence: request.body.delayed()))
        }
        await withThrowingTaskGroup(of: Void.self) { group in
            let portPromise = Promise<Int>()
            let logger = Logger(label: "Hummingbird")
            let server = childChannel.server(
                configuration: .init(address: .hostname(port: 0)),
                onServerRunning: { await portPromise.complete($0.localAddress!.port!) },
                eventLoopGroup: Self.eventLoopGroup,
                logger: logger
            )
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [server],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            let client = await TestClient(
                host: "localhost",
                port: portPromise.wait(),
                configuration: .init(),
                eventLoopGroupProvider: .createNew
            )
            group.addTask {
                do {
                    client.connect()
                    let response = try await client.get("/")
                    XCTAssertEqual(response.status, .ok)
                } catch {
                    XCTFail("Error: \(error)")
                }
            }
            // wait until we are sure handler has been called
            await handlerPromise.wait()
            // trigger graceful shutdown
            await serviceGroup.triggerGracefulShutdown()
        }
    }
}

struct DelayAsyncSequence<CoreSequence: AsyncSequence>: AsyncSequence {
    typealias Element = CoreSequence.Element
    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: CoreSequence.AsyncIterator

        mutating func next() async throws -> Element? {
            try await Task.sleep(for: .milliseconds(Int.random(in: 10..<100)))
            return try await self.iterator.next()
        }
    }

    let seq: CoreSequence

    func makeAsyncIterator() -> AsyncIterator {
        .init(iterator: self.seq.makeAsyncIterator())
    }
}

extension AsyncSequence {
    func delayed() -> DelayAsyncSequence<Self> {
        return .init(seq: self)
    }
}
