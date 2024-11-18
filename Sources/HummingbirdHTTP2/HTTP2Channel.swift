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
import NIOHTTP2
import NIOHTTPTypesHTTP2
import NIOSSL

/// Child channel for processing HTTP2
internal struct HTTP2Channel: ServerChildChannel {
    typealias HTTP2Connection = NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP2StreamChannel.Value>
    public struct Value: ServerChildChannelValue {
        let http2Connection: HTTP2Connection
        public let channel: Channel
    }

    /// HTTP2 configuration
    public struct Configuration: Sendable {
        /// Idle timeout, how long connection is kept idle before closing
        public var idleTimeout: Duration?
        /// Maximum amount of time to wait for client response before all streams are closed after second GOAWAY has been sent
        public var gracefulCloseTimeout: Duration?
        /// Maximum amount of time a connection can be open
        public var maxAgeTimeout: Duration?
        /// Configuration applied to HTTP2 stream channels
        public var streamConfiguration: HTTP1Channel.Configuration

        ///  Initialize HTTP2UpgradeChannel.Configuration
        /// - Parameters:
        ///   - idleTimeout: How long connection is kept idle before closing. A connection is considered idle when it has no open streams
        ///   - maxGraceCloseTimeout: Maximum amount of time to wait for client response before all streams are closed after second GOAWAY
        ///   - maxAgeTimeout: Maximum amount of time for a connection to be open.
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

    private let http2Stream: HTTP2StreamChannel
    public let configuration: Configuration

    ///  Initialize HTTP2Channel
    /// - Parameters:
    ///   - configuration: HTTP2 channel configuration
    ///   - responder: Function returning a HTTP response for a HTTP request
    public init(
        responder: @escaping HTTPChannelHandler.Responder,
        configuration: Configuration = .init()
    ) {
        self.configuration = configuration
        self.http2Stream = HTTP2StreamChannel(responder: responder, configuration: configuration.streamConfiguration)
    }

    /// Setup child channel for HTTP1 with HTTP2 upgrade
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        channel.eventLoop.makeCompletedFuture {
            let connectionManager = HTTP2ServerConnectionManager(
                eventLoop: channel.eventLoop,
                idleTimeout: self.configuration.idleTimeout,
                maxAgeTimeout: self.configuration.maxAgeTimeout,
                gracefulCloseTimeout: self.configuration.gracefulCloseTimeout
            )
            let handler: HTTP2Connection = try channel.pipeline.syncOperations.configureAsyncHTTP2Pipeline(
                mode: .server,
                streamDelegate: connectionManager.streamDelegate,
                configuration: .init()
            ) { http2ChildChannel in
                self.http2Stream.setup(channel: http2ChildChannel, logger: logger)
            }
            try channel.pipeline.syncOperations.addHandler(connectionManager)
            return .init(http2Connection: handler, channel: channel)
        }
    }

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value: Value, logger: Logger) async {
        do {
            try await withThrowingDiscardingTaskGroup { group in
                for try await client in value.http2Connection.inbound {
                    group.addTask {
                        await self.http2Stream.handle(value: client, logger: logger)
                    }
                }
            }
        } catch {
            logger.error("Error handling inbound connection for HTTP2 handler: \(error)")
        }
    }
}
