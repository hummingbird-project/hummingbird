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

import AsyncAlgorithms
import Atomics
import HummingbirdCoreAsync
@testable import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import XCTest

class HummingBirdCoreAsyncTests: XCTestCase {
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
        var logger = Logger(label: "HB")
        logger.logLevel = .trace
        try await testServer(
            childChannelSetup: HTTP1Channel(helloResponder),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: logger
        ) { client in
            let response = try await client.get("/")
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
    }

    func testError() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { _, _ in throw HBHTTPError(.unauthorized) },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            let response = try await client.get("/")
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers["content-length"].first, "0")
        }
    }

    func testConsumeBody() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { request, _ in
                let buffer = try await request.body.collect(upTo: .max)
                return HBHTTPResponse(status: .ok, body: .init(byteBuffer: buffer))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testWriteBody() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { _, _ in
                let buffer = self.randomBuffer(size: 1_140_000)
                return HBHTTPResponse(status: .ok, body: .init(byteBuffer: buffer))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            let response = try await client.get("/")
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readableBytes, 1_140_000)
        }
    }

    func testStreamBody() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { request, _ in
                return HBHTTPResponse(status: .ok, body: .init(asyncSequence: request.body))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            let buffer = self.randomBuffer(size: 1_140_000)
            let response = try await client.post("/", body: buffer)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testStreamBodyWriteSlow() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { request, _ in
                return HBHTTPResponse(status: .ok, body: .init(asyncSequence: request.body.delayed()))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
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
            public typealias OutboundOut = HTTPServerResponsePart

            func read(context: ChannelHandlerContext) {
                let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
                context.eventLoop.scheduleTask(in: .milliseconds(Int64.random(in: 5..<50))) {
                    loopBoundContext.value.read()
                }
            }
        }
        try await testServer(
            childChannelSetup: HTTP1Channel(additionalChannelHandlers: [SlowInputChannelHandler()]) { request, _ in
                return HBHTTPResponse(status: .ok, body: .init(asyncSequence: request.body.delayed()))
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
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
        try await testServer(
            childChannelSetup: HTTP1Channel(additionalChannelHandlers: [CreateErrorHandler()]) { request, _ in
                _ = try await request.body.collect(upTo: .max)
                return HBHTTPResponse(status: .ok)
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            let buffer = self.randomBuffer(size: 32)
            let response = try await client.post("/", body: buffer)
            XCTAssertEqual(response.status, .insufficientStorage)
        }
    }

    func testDropRequestBody() async throws {
        try await testServer(
            childChannelSetup: HTTP1Channel { _, _ in
                // ignore request body
                return HBHTTPResponse(status: .accepted)
            },
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
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
            childChannelSetup: HTTP1Channel(helloResponder),
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: Self.eventLoopGroup,
            logger: Logger(label: "HB")
        ) { client in
            try await withTimeout(.seconds(5)) {
                _ = try await client.get("/", headers: ["connection": "close"])
                let channel = try await client.channelPromise.futureResult.get()
                try await channel.closeFuture.get()
            }
        }
    }

    /*
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
     }*/
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
