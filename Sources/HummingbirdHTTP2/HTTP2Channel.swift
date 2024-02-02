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

import AsyncAlgorithms
import HTTPTypes
import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP2
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOHTTPTypesHTTP2
import NIOPosix
import NIOSSL
import ServiceLifecycle

/// Child channel for processing HTTP1 with the option of upgrading to HTTP2
public struct HTTP2UpgradeChannel: HTTPChannelHandler {
    public typealias Value = EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1Channel.Value, (NIOAsyncChannel<HTTP2Frame, HTTP2Frame>, NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP1Channel.Value>)>>

    private let sslContext: NIOSSLContext
    private let http1: HTTP1Channel
    private let idleTimeout: Duration
    private let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
    public var responder: @Sendable (HBRequest, Channel) async throws -> HBResponse { http1.responder }

    ///  Initialize HTTP1Channel
    /// - Parameters:
    ///   - tlsConfiguration: TLS configuration
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    ///   - responder: Function returning a HTTP response for a HTTP request
    public init(
        tlsConfiguration: TLSConfiguration,
        idleTimeout: Duration = .seconds(30),
        additionalChannelHandlers: @escaping @Sendable () -> [any RemovableChannelHandler] = { [] },
        responder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.idleTimeout = idleTimeout
        self.additionalChannelHandlers = additionalChannelHandlers
        self.http1 = HTTP1Channel(responder: responder, additionalChannelHandlers: additionalChannelHandlers)
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
            return http2ChildChannel.eventLoop.makeCompletedFuture {
                try http2ChildChannel.pipeline.syncOperations.addHandler(HTTP2FramePayloadToHTTPServerCodec())
                try http2ChildChannel.pipeline.syncOperations.addHandlers(childChannelHandlers)
                return try HTTP1Channel.Value(wrappingChannelSynchronously: http2ChildChannel)
            }
        }
    }

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value: Value, logger: Logger) async {
        struct HTTP2StreamState {
            var numberOfStreams: Int = 0
            var lastClose: ContinuousClock.Instant = .now
        }
        do {
            let channel = try await value.get()
            switch channel {
            case .http1_1(let http1):
                await handleHTTP(asyncChannel: http1, logger: logger)
            case .http2((let http2, let multiplexer)):
                enum MergeResult {
                    case gracefulShutdown
                    case timer
                    case stream(HTTP1Channel.Value)
                }
                // sequence to trigger graceful shutdown
                let (gracefulShutdownSequence, gracefulShutdownSource) = AsyncStream<Void>.makeStream()
                // timer sequence
                let timerSequence = AsyncTimerSequence(interval: self.idleTimeout, clock: .continuous)
                // merge multiplexer with graceful shutdown and timer
                let mergedSequence = merge(
                    multiplexer.inbound.map { MergeResult.stream($0) },
                    timerSequence.map { _ in .timer },
                    gracefulShutdownSequence.map { .gracefulShutdown }
                )
                do {
                    try await withGracefulShutdownHandler {
                        try await withThrowingDiscardingTaskGroup { group in
                            // stream state.
                            let streamState = NIOLockedValueBox(HTTP2StreamState())
                            loop:
                                for try await element in mergedSequence
                            {
                                switch element {
                                case .stream(let client):
                                    streamState.withLockedValue {
                                        $0.numberOfStreams += 1
                                    }
                                    group.addTask {
                                        await handleHTTP(asyncChannel: client, logger: logger)
                                        streamState.withLockedValue {
                                            $0.numberOfStreams -= 1
                                            $0.lastClose = .now
                                        }
                                    }
                                case .timer:
                                    let state = streamState.withLockedValue { $0 }
                                    if state.numberOfStreams == 0, state.lastClose + self.idleTimeout < .now {
                                        break loop
                                    }
                                case .gracefulShutdown:
                                    break loop
                                }
                            }
                        }
                    } onGracefulShutdown: {
                        gracefulShutdownSource.yield()
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
