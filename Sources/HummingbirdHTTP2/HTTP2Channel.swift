//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
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
import NIOHTTP1
import NIOHTTP2
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOHTTPTypesHTTP2
import NIOPosix
import NIOSSL
import NIOTLS

/// Child channel for processing HTTP1 with the option of upgrading to HTTP2
public struct HTTP2UpgradeChannel: HTTPChannelHandler {
    typealias HTTP1ConnectionOutput = HTTP1Channel.Value
    typealias HTTP2ConnectionOutput = NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP2StreamChannel.Value>
    public struct Value: ServerChildChannelValue {
        let negotiatedHTTPVersion: EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1ConnectionOutput, HTTP2ConnectionOutput>>
        public let channel: Channel
    }

    /// HTTP2 Upgrade configuration
    public struct Configuration: Sendable {
        /// Idle timeout, how long connection is kept idle before closing
        public var idleTimeout: Duration?
        /// Maximum amount of time to wait for client response before all streams are closed after second GOAWAY has been sent
        public var gracefulCloseTimeout: Duration?
        /// Maximum amount of time a connection can be open
        public var maxAgeTimeout: Duration?
        /// Configuration applieds to HTTP2 stream channels
        public var streamConfiguration: HTTP1Channel.Configuration

        ///  Initialize HTTP2UpgradeChannel.Configuration
        /// - Parameters:
        ///   - idleTimeout: How long connection is kept idle before closing
        ///   - maxGraceCloseTimeout: Maximum amount of time to wait for client response before all streams are closed after second GOAWAY
        ///   - streamConfiguration: Configuration applieds to HTTP2 stream channels
        public init(
            idleTimeout: Duration? = nil,
            gracefulCloseTimeout: Duration? = nil,
            maxAgeTimeout: Duration? = nil,
            streamConfiguration: HTTP1Channel.Configuration = .init()
        ) {
            self.idleTimeout = idleTimeout
            self.gracefulCloseTimeout = gracefulCloseTimeout
            self.streamConfiguration = streamConfiguration
        }
    }

    private let sslContext: NIOSSLContext
    private let http1: HTTP1Channel
    private let http2Stream: HTTP2StreamChannel
    public let configuration: Configuration
    public var responder: Responder {
        self.http2Stream.responder
    }

    ///  Initialize HTTP2Channel
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to add to stream channel pipeline after HTTP part decoding and
    ///       before HTTP request handling
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
        self.configuration = .init()
        self.http1 = HTTP1Channel(
            responder: responder,
            configuration: .init(additionalChannelHandlers: additionalChannelHandlers())
        )
        self.http2Stream = HTTP2StreamChannel(
            responder: responder,
            configuration: .init(additionalChannelHandlers: additionalChannelHandlers())
        )
    }

    ///  Initialize HTTP2Channel
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - configuration: HTTP2 channel configuration
    ///   - responder: Function returning a HTTP response for a HTTP request
    public init(
        tlsConfiguration: TLSConfiguration,
        configuration: Configuration = .init(),
        responder: @escaping HTTPChannelHandler.Responder
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.configuration = configuration
        self.http1 = HTTP1Channel(responder: responder, configuration: configuration.streamConfiguration)
        self.http2Stream = HTTP2StreamChannel(responder: responder, configuration: configuration.streamConfiguration)
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

        return channel.configureHTTP2AsyncSecureUpgrade { channel in
            self.http1.setup(channel: channel, logger: logger)
        } http2ConnectionInitializer: { channel in
            channel.eventLoop.makeCompletedFuture {
                let connectionManager = HTTP2ServerConnectionManager(
                    eventLoop: channel.eventLoop,
                    idleTimeout: self.configuration.idleTimeout,
                    maxAgeTimeout: self.configuration.maxAgeTimeout,
                    gracefulCloseTimeout: self.configuration.gracefulCloseTimeout
                )
                let handler: HTTP2ConnectionOutput = try channel.pipeline.syncOperations.configureAsyncHTTP2Pipeline(
                    mode: .server,
                    streamDelegate: connectionManager.streamDelegate,
                    configuration: .init()
                ) { http2ChildChannel in
                    self.http2Stream.setup(channel: http2ChildChannel, logger: logger)
                }
                try channel.pipeline.syncOperations.addHandler(connectionManager)
                return handler
            }
        }
        .map {
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
                await self.http1.handle(value: http1, logger: logger)
            case .http2(let multiplexer):
                do {
                    try await withThrowingDiscardingTaskGroup { group in
                        for try await client in multiplexer.inbound {
                            group.addTask {
                                await self.http2Stream.handle(value: client, logger: logger)
                            }
                        }
                    }
                } catch {
                    logger.error("Error handling inbound connection for HTTP2 handler: \(error)")
                }
            }
        } catch {
            logger.error("Error getting HTTP2 upgrade negotiated value: \(error)")
        }
    }
}

// Code taken from NIOHTTP2
extension Channel {
    /// Configures a channel to perform an HTTP/2 secure upgrade with typed negotiation results.
    ///
    /// HTTP/2 secure upgrade uses the Application Layer Protocol Negotiation TLS extension to
    /// negotiate the inner protocol as part of the TLS handshake. For this reason, until the TLS
    /// handshake is complete, the ultimate configuration of the channel pipeline cannot be known.
    ///
    /// This function configures the channel with a pair of callbacks that will handle the result
    /// of the negotiation. It explicitly **does not** configure a TLS handler to actually attempt
    /// to negotiate ALPN. The supported ALPN protocols are provided in
    /// `NIOHTTP2SupportedALPNProtocols`: please ensure that the TLS handler you are using for your
    /// pipeline is appropriately configured to perform this protocol negotiation.
    ///
    /// If negotiation results in an unexpected protocol, the pipeline will close the connection
    /// and no callback will fire.
    ///
    /// This configuration is acceptable for use on both client and server channel pipelines.
    ///
    /// - Parameters:
    ///   - http1ConnectionInitializer: A callback that will be invoked if HTTP/1.1 has been explicitly
    ///         negotiated, or if no protocol was negotiated. Must return a future that completes when the
    ///         channel has been fully mutated.
    ///   - http2ConnectionInitializer: A callback that will be invoked if HTTP/2 has been negotiated, and that
    ///         should configure the channel for HTTP/2 use. Must return a future that completes when the
    ///         channel has been fully mutated.
    /// - Returns: An `EventLoopFuture` of an `EventLoopFuture` containing the `NIOProtocolNegotiationResult` that completes when the channel
    ///     is ready to negotiate.
    @inlinable
    internal func configureHTTP2AsyncSecureUpgrade<HTTP1Output: Sendable, HTTP2Output: Sendable>(
        http1ConnectionInitializer: @escaping NIOChannelInitializerWithOutput<HTTP1Output>,
        http2ConnectionInitializer: @escaping NIOChannelInitializerWithOutput<HTTP2Output>
    ) -> EventLoopFuture<EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1Output, HTTP2Output>>> {
        let alpnHandler = NIOTypedApplicationProtocolNegotiationHandler<NIONegotiatedHTTPVersion<HTTP1Output, HTTP2Output>>() { result in
            switch result {
            case .negotiated("h2"):
                // Successful upgrade to HTTP/2. Let the user configure the pipeline.
                return http2ConnectionInitializer(self).map { http2Output in .http2(http2Output) }
            case .negotiated("http/1.1"), .fallback:
                // Explicit or implicit HTTP/1.1 choice.
                return http1ConnectionInitializer(self).map { http1Output in .http1_1(http1Output) }
            case .negotiated:
                // We negotiated something that isn't HTTP/1.1. This is a bad scene, and is a good indication
                // of a user configuration error. We're going to close the connection directly.
                return self.close().flatMap { self.eventLoop.makeFailedFuture(NIOHTTP2Errors.invalidALPNToken()) }
            }
        }

        return self.pipeline
            .addHandler(alpnHandler)
            .flatMap { _ in
                self.pipeline.handler(type: NIOTypedApplicationProtocolNegotiationHandler<NIONegotiatedHTTPVersion<HTTP1Output, HTTP2Output>>.self).map { alpnHandler in
                    alpnHandler.protocolNegotiationResult
                }
            }
    }
}
