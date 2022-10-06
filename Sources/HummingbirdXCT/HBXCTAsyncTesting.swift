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
struct HBXCTAsyncTesting: HBXCT {
    init(timeout: TimeAmount) {
        self.asyncTestingChannel = .init()
        self.asyncTestingEventLoop = self.asyncTestingChannel.testingEventLoop
        self.timeout = timeout
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
        let promise = self.asyncTestingEventLoop.makePromise(of: Void.self)
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
            try self.asyncTestingEventLoop.syncShutdownGracefully()
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
        let promise = self.asyncTestingEventLoop.makePromise(of: HBXCTResponse.self)
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

            await self.asyncTestingEventLoop.run()

            // read response
            let outbound = try await readOutbound()
            guard case .head(let head) = outbound else { throw HBXCTError.noHead }
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

    var eventLoopGroup: EventLoopGroup { return self.asyncTestingEventLoop }

    func writeInbound(_ part: HTTPServerRequestPart) async throws {
        try await self.asyncTestingChannel.writeInbound(part)
    }

    func readOutbound() async throws -> HTTPServerResponsePart? {
        let deadline: NIODeadline = .now() + self.timeout
        while NIODeadline.now() < deadline {
            if let part = try await self.asyncTestingChannel.readOutbound(as: HTTPServerResponsePart.self) {
                return part
            }
            // sleep a millisecond
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw HBXCTError.timeout
    }

    let asyncTestingChannel: NIOAsyncTestingChannel
    let asyncTestingEventLoop: NIOAsyncTestingEventLoop
    let timeout: TimeAmount
}

#endif // compiler(>=5.5.2) && canImport(_Concurrency)
