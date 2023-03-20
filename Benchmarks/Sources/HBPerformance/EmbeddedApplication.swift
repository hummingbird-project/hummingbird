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
import NIOCore
import NIOEmbedded
import NIOHTTP1
import XCTest

/// Test application by running on an EmbeddedChannel
public struct HBEmbeddedApplication {
    /// Response structure returned by XCT testing framework
    public struct Response {
        /// response status
        public let status: HTTPResponseStatus
        /// response headers
        public let headers: HTTPHeaders
        /// response body
        public let body: ByteBuffer?
    }

    struct Error: Swift.Error, Equatable {
        private enum _Internal {
            case noHead
            case illegalBody
            case noEnd
        }

        private let value: _Internal
        private init(_ value: _Internal) {
            self.value = value
        }

        static var noHead: Self { .init(.noHead) }
        static var illegalBody: Self { .init(.illegalBody) }
        static var noEnd: Self { .init(.noEnd) }
    }

    let embeddedChannel: EmbeddedChannel
    let embeddedEventLoop: EmbeddedEventLoop
    let application: HBApplication

    public init(configuration: HBApplication.Configuration) {
        self.embeddedChannel = EmbeddedChannel()
        self.embeddedEventLoop = self.embeddedChannel.embeddedEventLoop
        self.application = HBApplication(configuration: configuration, eventLoopGroupProvider: .shared(self.embeddedEventLoop))
    }

    /// Start tests
    public func start() throws {
        self.application.server.addChannelHandler(BreakupHTTPBodyChannelHandler())
        try self.embeddedChannel.pipeline.addHandlers(
            self.application.server.getChildChannelHandlers(responder: HBApplication.HTTPResponder(application: self.application))
        ).wait()
    }

    /// Stop tests
    public func stop() {
        do {
            try self.application.shutdownApplication()
            _ = try self.embeddedChannel.finish()
            try self.embeddedEventLoop.syncShutdownGracefully()
        } catch {
            fatalError("\(error)")
        }
    }

    /// Send request and call test callback on the response returned
    public func execute(
        uri: String,
        method: HTTPMethod,
        headers: HTTPHeaders = [:],
        body: ByteBuffer? = nil
    ) -> EventLoopFuture<Self.Response> {
        do {
            // write request
            let requestHead = HTTPRequestHead(version: .init(major: 1, minor: 1), method: method, uri: uri, headers: headers)
            try writeInbound(.head(requestHead))
            if let body = body {
                try self.writeInbound(.body(body))
            }
            try self.writeInbound(.end(nil))

            self.embeddedChannel.embeddedEventLoop.run()

            // read response
            guard case .head(let head) = try readOutbound() else { throw Error.noHead }
            var next = try readOutbound()
            var buffer = self.embeddedChannel.allocator.buffer(capacity: 0)
            while case .body(let part) = next {
                guard case .byteBuffer(var b) = part else { throw Error.illegalBody }
                buffer.writeBuffer(&b)
                next = try readOutbound()
            }
            guard case .end = next else { throw Error.noEnd }

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
                let size = min(32768, buffer.readableBytes)
                let slice = buffer.readSlice(length: size)!
                context.fireChannelRead(self.wrapInboundOut(.body(slice)))
            }
        }
    }
}
