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

/// Child channel for processing HTTP1 with the option of upgrading to HTTP2
public struct HTTP2UpgradeChannel: HTTPChannelHandler {
    public struct Value: ServerChildChannelValue {
        let negotiatedHTTPVersion: EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1Channel.Value, (NIOAsyncChannel<HTTP2Frame, HTTP2Frame>, NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP1Channel.Value>)>>
        public let channel: Channel
    }

    /// HTTP2 Upgrade configuration
    public struct Configuration: Sendable {
        /// Configuration applieds to HTTP2 stream channels
        public var streamConfiguration: HTTP1Channel.Configuration

        ///  Initialize HTTP2UpgradeChannel.Configuration
        /// - Parameters:
        ///   - additionalChannelHandlers: Additional channel handlers to add to HTTP2 connection channel
        ///   - streamConfiguration: Configuration applieds to HTTP2 stream channels
        public init(
            streamConfiguration: HTTP1Channel.Configuration = .init()
        ) {
            self.streamConfiguration = streamConfiguration
        }
    }

    private let sslContext: NIOSSLContext
    private let http1: HTTP1Channel
    public var responder: HTTPChannelHandler.Responder { self.http1.responder }

    ///  Initialize HTTP2Channel
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    ///   - responder: Function returning a HTTP response for a HTTP request
    @available(*, deprecated, renamed: "HTTP1Channel(tlsConfiguration:configuration:responder:)")
    public init(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @escaping @Sendable () -> [any RemovableChannelHandler],
        responder: @escaping HTTPChannelHandler.Responder
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.http1 = HTTP1Channel(responder: responder, configuration: .init(additionalChannelHandlers: additionalChannelHandlers()))
    }

    ///  Initialize HTTP2Channel
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    ///   - responder: Function returning a HTTP response for a HTTP request
    public init(
        tlsConfiguration: TLSConfiguration,
        configuration: Configuration = .init(),
        responder: @escaping HTTPChannelHandler.Responder
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.http1 = HTTP1Channel(responder: responder, configuration: configuration.streamConfiguration)
    }

    /// Setup child channel for HTTP1 with HTTP2 upgrade
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        do {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: self.sslContext))
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
        }

        return channel.configureAsyncHTTPServerPipeline { http1Channel -> EventLoopFuture<HTTP1Channel.Value> in
            return http1Channel.eventLoop.makeCompletedFuture {
                try http1Channel.pipeline.syncOperations.addHandler(HTTP1ToHTTPServerCodec(secure: true))
                try http1Channel.pipeline.syncOperations.addHandlers(self.http1.configuration.additionalChannelHandlers())
                if let idleTimeout = self.http1.configuration.idleTimeout {
                    try http1Channel.pipeline.syncOperations.addHandler(IdleStateHandler(readTimeout: idleTimeout))
                }
                try http1Channel.pipeline.syncOperations.addHandler(HTTPUserEventHandler(logger: logger))
                return try HTTP1Channel.Value(wrappingChannelSynchronously: http1Channel)
            }
        } http2ConnectionInitializer: { http2Channel -> EventLoopFuture<NIOAsyncChannel<HTTP2Frame, HTTP2Frame>> in
            http2Channel.eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<HTTP2Frame, HTTP2Frame>(wrappingChannelSynchronously: http2Channel)
            }
        } http2StreamInitializer: { http2ChildChannel -> EventLoopFuture<HTTP1Channel.Value> in
            return http2ChildChannel.eventLoop.makeCompletedFuture {
                try http2ChildChannel.pipeline.syncOperations.addHandler(HTTP2FramePayloadToHTTPServerCodec())
                try http2ChildChannel.pipeline.syncOperations.addHandlers(self.http1.configuration.additionalChannelHandlers())
                if let idleTimeout = self.http1.configuration.idleTimeout {
                    try http2ChildChannel.pipeline.syncOperations.addHandler(IdleStateHandler(readTimeout: idleTimeout))
                }
                try http2ChildChannel.pipeline.syncOperations.addHandler(HTTPUserEventHandler(logger: logger))
                return try HTTP1Channel.Value(wrappingChannelSynchronously: http2ChildChannel)
            }
        }.map {
            .init(negotiatedHTTPVersion: $0, channel: channel)
        }
    }

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value: Value, logger: Logger) async {
        do {
            let channel = try await value.negotiatedHTTPVersion.get()
            switch channel {
            case .http1_1(let http1):
                await handleHTTP(asyncChannel: http1, logger: logger)
            case .http2((let http2, let multiplexer)):
                do {
                    try await withThrowingDiscardingTaskGroup { group in
                        for try await client in multiplexer.inbound.cancelOnGracefulShutdown() {
                            group.addTask {
                                await handleHTTP(asyncChannel: client, logger: logger)
                            }
                        }
                    }
                } catch {
                    logger.error("Error handling inbound connection for HTTP2 handler: \(error)")
                }
                // have to run this to ensure http2 channel outbound writer is closed
                try await http2.executeThenClose { _, _ in }
            }
        } catch {
            logger.error("Error getting HTTP2 upgrade negotiated value: \(error)")
        }
    }
}
