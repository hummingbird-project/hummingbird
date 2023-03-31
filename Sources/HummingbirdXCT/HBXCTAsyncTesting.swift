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

import Hummingbird
import HummingbirdCore
import NIOCore
import NIOEmbedded
import NIOHTTP1
import XCTest

/// Test application by running on an EmbeddedChannel
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct HBXCTAsyncTesting: HBXCT {
    typealias HBHTTPServerRequestPart = HTTPPart<HTTPRequestHead, ByteBuffer>
    typealias HBHTTPServerResponsePart = HTTPPart<HTTPResponseHead, ByteBuffer>

    init(timeout: TimeAmount) {
        self.asyncTestingChannel = .init()
        self.asyncTestingEventLoop = self.asyncTestingChannel.testingEventLoop
        self.timeout = timeout
    }

    /// Start tests
    func start(application: HBApplication) {
        application.server.addChannelHandler(HBHTTPConvertChannel())
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
        let deadline: NIODeadline = .now() + self.timeout
        // write request
        let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
        try await writeInbound(.head(requestHead))
        if let body = body {
            try await self.writeInbound(.body(body))
        }
        try await self.writeInbound(.end(nil))

        await self.asyncTestingEventLoop.run()

        // read response
        let outbound = try await readOutbound(deadline: deadline)
        guard case .head(let head) = outbound else { throw HBXCTError.noHead }
        var next = try await readOutbound(deadline: deadline)
        var buffer = self.asyncTestingChannel.allocator.buffer(capacity: 0)
        while case .body(var b) = next {
            buffer.writeBuffer(&b)
            next = try await self.readOutbound(deadline: deadline)
        }
        guard case .end = next else { throw HBXCTError.noEnd }

        return .init(status: head.status, headers: head.headers, body: buffer)
    }

    var eventLoopGroup: EventLoopGroup { return self.asyncTestingEventLoop }

    func writeInbound(_ part: HBHTTPServerRequestPart) async throws {
        try await self.asyncTestingChannel.writeInbound(part)
    }

    func readOutbound(deadline: NIODeadline) async throws -> HBHTTPServerResponsePart? {
        return try await withThrowingTaskGroup(of: HBHTTPServerResponsePart.self) { group in
            defer {
                group.cancelAll()
            }
            group.addTask { try await self.asyncTestingChannel.waitForOutboundWrite(as: HBHTTPServerResponsePart.self) }
            group.addTask {
                let timeout = deadline - .now()
                if timeout > .nanoseconds(0) {
                    try await Task.sleep(nanoseconds: numericCast(self.timeout.nanoseconds))
                } else {
                    try Task.checkCancellation()
                }
                throw HBXCTError.timeout
            }
            let result = try await group.next()
            return result
        }
    }

    let asyncTestingChannel: NIOAsyncTestingChannel
    let asyncTestingEventLoop: NIOAsyncTestingEventLoop
    let timeout: TimeAmount

    /// Channel to convert HTTPServerResponsePart to the Sendable type HBHTTPServerResponsePart
    private final class HBHTTPConvertChannel: ChannelOutboundHandler, RemovableChannelHandler {
        typealias OutboundIn = HTTPServerResponsePart
        typealias OutboundOut = HBHTTPServerResponsePart

        func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
            let part = unwrapOutboundIn(data)
            switch part {
            case .head(let head):
                context.write(self.wrapOutboundOut(.head(head)), promise: promise)
            case .body(let body):
                switch body {
                case .byteBuffer(let buffer):
                    context.write(self.wrapOutboundOut(.body(buffer)), promise: promise)
                default:
                    preconditionFailure("HBXCTAsyncTesting only supports ByteBuffer body parts")
                }
            case .end:
                context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
            }
        }
    }
}
