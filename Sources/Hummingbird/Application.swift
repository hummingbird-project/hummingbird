//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
import Dispatch
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import UnixSignals

/// Where should the application get its EventLoopGroup from
public enum EventLoopGroupProvider {
    /// Use this EventLoopGroup
    case shared(EventLoopGroup)
    /// Use one of the singleton EventLoopGroups
    case singleton

    public var eventLoopGroup: EventLoopGroup {
        switch self {
        case .singleton:
            #if os(iOS)
            return NIOTSEventLoopGroup.singleton
            #else
            return MultiThreadedEventLoopGroup.singleton
            #endif
        case .shared(let elg):
            return elg
        }
    }
}

public final class HBApplicationContext: Sendable {
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// Configuration
    public let configuration: HBApplicationConfiguration
    /// Logger
    public let logger: Logger
    /// Encoder used by router
    public let encoder: HBResponseEncoder
    /// decoder used by router
    public let decoder: HBRequestDecoder

    public init(
        threadPool: NIOThreadPool,
        configuration: HBApplicationConfiguration,
        logger: Logger,
        encoder: HBResponseEncoder,
        decoder: HBRequestDecoder
    ) {
        self.threadPool = threadPool
        self.configuration = configuration
        self.logger = logger
        self.encoder = encoder
        self.decoder = decoder
    }
}

public protocol HBApplication: Service, CustomStringConvertible {
    associatedtype Context: HBRequestContext = HBBasicRequestContext
    associatedtype Responder: HBResponder<Context>
    associatedtype ChannelSetup: HBChannelSetup & HTTPChannelHandler = HTTP1Channel

    /// Responder
    func buildResponder() async throws -> Responder
    /// Server channel setup
    func buildChannelSetup(httpResponder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse) -> ChannelSetup

    /// event loop group used by application
    var eventLoopGroup: EventLoopGroup { get }
    /// thread pool used by application
    var threadPool: NIOThreadPool { get }
    /// Configuration
    var configuration: HBApplicationConfiguration { get }
    /// Logger
    var logger: Logger { get }
    /// Encoder used by router
    var encoder: HBResponseEncoder  { get }
    /// decoder used by router
    var decoder: HBRequestDecoder { get }
    /// on server running
    @Sendable func onServerRunning(_ channel: Channel) async 
    /// services attached to the application.
    var services: [any Service] { get }
}

extension HBApplication where ChannelSetup == HTTP1Channel {
    public func buildChannelSetup(httpResponder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse) -> ChannelSetup {
        HTTP1Channel(responder: httpResponder)
    }
}

extension HBApplication {
    /// event loop group used by application
    public var eventLoopGroup: EventLoopGroup { MultiThreadedEventLoopGroup.singleton }
    /// thread pool used by application
    public var threadPool: NIOThreadPool { NIOThreadPool.singleton }
    /// Configuration
    public var configuration: HBApplicationConfiguration { .init() }
    /// Logger
    public var logger: Logger { Logger(label: configuration.serverName ?? "HummingBird") }
    /// Encoder used by router
    public var encoder: HBResponseEncoder  { NullEncoder() }
    /// decoder used by router
    public var decoder: HBRequestDecoder { NullDecoder() }
    /// on server running
    public func onServerRunning(_ channel: Channel) async {}
    /// services attached to the application.
    public var services: [any Service] { [] }
}

/// Conform to `Service` from `ServiceLifecycle`.
extension HBApplication {
    public func run() async throws {
        let context = HBApplicationContext(
            threadPool: self.threadPool,
            configuration: self.configuration,
            logger: self.logger,
            encoder: self.encoder,
            decoder: self.decoder
        )
        let dateCache = HBDateCache()
        let responder = try await self.buildResponder()
        @Sendable func respond(to request: HBHTTPRequest, channel: Channel) async throws -> HBHTTPResponse {
            let request = HBRequest(
                head: request.head,
                body: request.body
            )
            let context = Self.Responder.Context(
                applicationContext: context,
                channel: channel,
                logger: loggerWithRequestId(context.logger)
            )
            // respond to request
            var response = try await responder.respond(to: request, context: context)
            response.headers.add(name: "date", value: dateCache.date)
            // server name header
            if let serverName = self.configuration.serverName {
                response.headers.add(name: "server", value: serverName)
            }
            return HBHTTPResponse(status: response.status, headers: response.headers, body: response.body)
        }
        // update channel with responder
        let channelSetup = self.buildChannelSetup(httpResponder: respond)
        // create server
        let server = HBServer(
            childChannelSetup: channelSetup,
            configuration: self.configuration.httpServer,
            onServerRunning: self.onServerRunning,
            eventLoopGroup: self.eventLoopGroup,
            logger: self.logger
        )
        try await withGracefulShutdownHandler {
            let services: [any Service] = [server, dateCache] + self.services
            let serviceGroup = ServiceGroup(
                configuration: .init(services: services, logger: self.logger)
            )
            try await serviceGroup.run()
        } onGracefulShutdown: {
            Task {
                try await server.shutdownGracefully()
            }
        }
    }

    /// Helper function that runs application inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGINT, SIGTERM
    public func runService(gracefulShutdownSignals: [UnixSignal] = [.sigterm, .sigint]) async throws {
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [self],
                gracefulShutdownSignals: gracefulShutdownSignals,
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}

extension HBApplication {
    public var description: String { "HBApplication" }
}

extension Logger {
    /// Create new Logger with additional metadata value
    /// - Parameters:
    ///   - metadataKey: Metadata key
    ///   - value: Metadata value
    /// - Returns: Logger
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}

/// Current global request ID
private let globalRequestID = ManagedAtomic(0)

public func loggerWithRequestId(_ logger: Logger) -> Logger {
    let requestId = globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
    return logger.with(metadataKey: "hb_id", value: .stringConvertible(requestId))
}
