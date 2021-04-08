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
import NIO
import NIOHTTP1
import XCTest

/// Test application by running on an EmbeddedChannel
struct HBXCTEmbedded: HBXCT {
    init() {
        self.embeddedChannel = EmbeddedChannel()
        self.embeddedEventLoop = self.embeddedChannel.embeddedEventLoop
    }

    /// Start tests
    func start(application: HBApplication) {
        application.server.addChannelHandler(BreakupHTTPBodyChannelHandler())
        XCTAssertNoThrow(
            try self.embeddedChannel.pipeline.addHandlers(
                application.server.getChildChannelHandlers(responder: HBApplication.HTTPResponder(application: application))
            ).wait()
        )
    }

    /// Stop tests
    func stop(application: HBApplication) {
        try? application.shutdownApplication()
        XCTAssertNoThrow(_ = try self.embeddedChannel.finish())
        XCTAssertNoThrow(_ = try self.embeddedEventLoop.syncShutdownGracefully())
    }

    /// Send request and call test callback on the response returned
    func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<HBXCTResponse> {
        do {
            // write request
            let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
            try writeInbound(.head(requestHead))
            if let body = body {
                try self.writeInbound(.body(body))
            }
            try self.writeInbound(.end(nil))

            // flush
            self.embeddedChannel.flush()

            // read response
            guard case .head(let head) = try readOutbound() else { throw HBXCTError.noHead }
            var next = try readOutbound()
            var buffer = self.embeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw HBXCTError.illegalBody }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { throw HBXCTError.noEnd }

            return self.embeddedEventLoop.makeSucceededFuture(.init(status: head.status, headers: head.headers, body: buffer))
        } catch {
            return self.embeddedEventLoop.makeFailedFuture(error)
        }
    }

    var eventLoopGroup: EventLoopGroup { return self.embeddedEventLoop }

    func writeInbound(_ part: HTTPServerRequestPart) throws {
        try self.embeddedChannel.writeInbound(part)
    }

    func readOutbound() throws -> HTTPServerResponsePart? {
        return try self.embeddedChannel.readOutbound(as: HTTPServerResponsePart.self)
    }

    let embeddedChannel: EmbeddedChannel
    let embeddedEventLoop: EmbeddedEventLoop
}

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
                let size = min(Int.random(in: 16...65536), buffer.readableBytes)
                let slice = buffer.readSlice(length: size)!
                context.fireChannelRead(self.wrapInboundOut(.body(slice)))
            }
        }
    }
}
