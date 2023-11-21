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

import HTTPTypes
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP2
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOHTTPTypesHTTP2
import NIOPosix
import NIOSSL

public struct HTTP2Channel: HTTPChannelHandler {
    public typealias Value = EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1Channel.Value, (NIOAsyncChannel<HTTP2Frame, HTTP2Frame>, NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP1Channel.Value>)>>

    private let sslContext: NIOSSLContext
    private var http1: HTTP1Channel
    private let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
    public var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse {
        get { http1.responder }
        set { http1.responder = newValue }
    }

    public init(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
        responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.additionalChannelHandlers = additionalChannelHandlers
        self.http1 = HTTP1Channel(additionalChannelHandlers: additionalChannelHandlers(), responder: responder)
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value> {
        do {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: self.sslContext))
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
        }

        return channel.configureAsyncHTTPServerPipeline { http1Channel -> EventLoopFuture<HTTP1Channel.Value> in
            let childChannelHandlers: [ChannelHandler] =
                [HTTP1ToHTTPServerCodec(secure: false)] +
                self.additionalChannelHandlers() +
                [HBHTTPUserEventHandler(logger: logger)]

            return http1Channel
                .pipeline
                .addHandlers(childChannelHandlers)
                .flatMapThrowing {
                    try HTTP1Channel.Value(wrappingChannelSynchronously: http1Channel)
                }
        } http2ConnectionInitializer: { http2Channel -> EventLoopFuture<NIOAsyncChannel<HTTP2Frame, HTTP2Frame>> in
            http2Channel.eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<HTTP2Frame, HTTP2Frame>(wrappingChannelSynchronously: http2Channel)
            }
        } http2StreamInitializer: { http2ChildChannel -> EventLoopFuture<HTTP1Channel.Value> in
            let childChannelHandlers: [ChannelHandler] =
                self.additionalChannelHandlers() + [
                    HBHTTPUserEventHandler(logger: logger),
                ]

            return http2ChildChannel
                .pipeline
                .addHandler(HTTP2FramePayloadToHTTPClientCodec())
                .flatMap {
                    http2ChildChannel.pipeline.addHandlers(childChannelHandlers)
                }.flatMapThrowing {
                    try HTTP1Channel.Value(wrappingChannelSynchronously: http2ChildChannel)
                }
        }
    }

    public func handle(value: Value, logger: Logger) async {
        do {
            let channel = try await value.get()
            switch channel {
            case .http1_1(let http1):
                await handleHTTP(asyncChannel: http1, logger: logger)
            case .http2((let http2, let multiplexer)):
                try await withThrowingDiscardingTaskGroup { group in
                    for try await client in multiplexer.inbound.cancelOnGracefulShutdown() {
                        group.addTask {
                            await handleHTTP(asyncChannel: client, logger: logger)
                        }
                    }
                }

                // Close the `http2` NIOAsyncCannel here. Closing it here ensures we retain the `http2` instance,
                // preventing it from being `deinit`-ed.
                // Not having this will cause HTTP2 connections to close shortly after the first request
                // is handled. When NIOAsyncChannel `deinit`s, it closes the channel. So this ensures
                // that closing the HTTP2 channel happens when we need it to.
                try await http2.channel.close()
            }
        } catch {
            logger.error("Error handling inbound connection for HTTP2 handler: \(error)")
        }
    }
}
