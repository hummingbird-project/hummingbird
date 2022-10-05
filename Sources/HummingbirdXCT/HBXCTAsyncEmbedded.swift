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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import Hummingbird
import NIOCore
import NIOEmbedded
import NIOHTTP1
import XCTest

/// Test application by running on an EmbeddedChannel
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct HBXCTAsyncEmbedded: HBXCT {
    init() {
        self.asyncTestingChannel = .init()
        self.testingEventLoop = self.asyncTestingChannel.testingEventLoop
    }

    /// Start tests
    func start(application: HBApplication) {
        application.server.addChannelHandler(BreakupHTTPBodyChannelHandler())
        XCTAssertNoThrow(
            try self.asyncTestingChannel.pipeline.addHandlers(
                application.server.getChildChannelHandlers(responder: HBApplication.HTTPResponder(application: application))
            ).wait()
        )
    }

    /// EventLoop version of stop
    func stop(application: HBApplication) {
        let promise = self.testingEventLoop.makePromise(of: Void.self)
        promise.completeWithTask {
            try await self._stop(application: application)
        }
        try? promise.futureResult.wait()
    }

    /// Stop tests
    func _stop(application: HBApplication) async throws {
        do {
            try application.shutdownApplication()
            _ = try await self.asyncTestingChannel.finish()
            try self.testingEventLoop.syncShutdownGracefully()
        } catch {
            XCTFail("\(error)")
        }
    }

    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<HBXCTResponse> {
        let promise = self.testingEventLoop.makePromise(of: HBXCTResponse.self)
        promise.completeWithTask {
            try await self._execute(uri: uri, method: method, headers: headers, body: body)
        }
        return promise.futureResult
    }

    /// Send request and call test callback on the response returned
    func _execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders,
        body: ByteBuffer?
    ) async throws -> HBXCTResponse {
        do {
            // write request
            let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
            try await writeInbound(.head(requestHead))
            if let body = body {
                try await self.writeInbound(.body(body))
            }
            try await self.writeInbound(.end(nil))

            await self.asyncTestingChannel.testingEventLoop.run()

            // read response
            guard case .head(let head) = try await readOutbound() else { throw HBXCTError.noHead }
            var next = try await readOutbound()
            var buffer = self.asyncTestingChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw HBXCTError.illegalBody }
                buffer.writeBuffer(&b)
                next = try await readOutbound()
            }
            guard case .end = next else { throw HBXCTError.noEnd }

            return .init(status: head.status, headers: head.headers, body: buffer)
        }
    }

    var eventLoopGroup: EventLoopGroup { return self.testingEventLoop }

    func writeInbound(_ part: HTTPServerRequestPart) async throws {
        try await self.asyncTestingChannel.writeInbound(part)
    }

    func readOutbound() async throws -> HTTPServerResponsePart? {
        return try await self.asyncTestingChannel.readOutbound(as: HTTPServerResponsePart.self)
    }

    let asyncTestingChannel: NIOAsyncTestingChannel
    let testingEventLoop: NIOAsyncTestingEventLoop
}

#endif // compiler(>=5.5.2) && canImport(_Concurrency)
