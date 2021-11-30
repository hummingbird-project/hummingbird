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

#if compiler(>=5.5) && canImport(_Concurrency)

import HummingbirdCore
import HummingbirdCoreXCT
import NIOCore
import NIOPosix
import XCTest

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class HummingBirdCoreAsyncTests: XCTestCase {
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

    func testStreamBody() throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard ProcessInfo.processInfo.environment["CI"] != "true" else { throw XCTSkip() }
        #endif
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
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
