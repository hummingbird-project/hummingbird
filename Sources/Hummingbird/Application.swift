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

/// Application class. Brings together all the components of Hummingbird together
///
/// ```
/// let router = HBRouterBuilder()
/// router.middleware.add(MyMiddleware())
/// router.get("hello") { _ in
///     return "hello"
/// }
/// let app = HBApplication(responder: router.buildResponder())
/// try await app.runService()
/// ```
/// Editing the application setup after calling `runService` will produce undefined behaviour.
public struct HBApplication<Responder: HBResponder, ChannelSetup: HBChannelSetup & HTTPChannelHandler> {
    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public let responder: Responder
    /// Configuration
    public var configuration: HBApplicationConfiguration
    /// Logger
    public var logger: Logger
    /// Encoder used by router
    public var encoder: HBResponseEncoder
    /// decoder used by router
    public var decoder: HBRequestDecoder
    /// on server running
    public var onServerRunning: @Sendable (Channel) async -> Void
    /// Server channel setup
    let channelSetup: ChannelSetup
    /// services attached to the application.
    var services: [any Service]

    // MARK: Initialization

    /// Initialize new Application
    public init(
        responder: Responder,
        channelSetup: ChannelSetup = HTTP1Channel(),
        configuration: HBApplicationConfiguration = HBApplicationConfiguration(),
        threadPool: NIOThreadPool = .singleton,
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.responder = responder
        self.channelSetup = channelSetup
        self.configuration = configuration
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()
        self.onServerRunning = { _ in }

        self.eventLoopGroup = eventLoopGroupProvider.eventLoopGroup
        self.threadPool = threadPool
        self.services = []
    }

    // MARK: Methods

    ///  Add service to be managed by application ServiceGroup
    /// - Parameter service: service to be added
    public mutating func addService(_ service: any Service) {
        self.services.append(service)
    }

    public static func loggerWithRequestId(_ logger: Logger) -> Logger {
        let requestId = globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
        return logger.with(metadataKey: "hb_id", value: .stringConvertible(requestId))
    }
}

/// Conform to `Service` from `ServiceLifecycle`.
extension HBApplication: Service where Responder.Context: HBRequestContext {
    public func run() async throws {
        let context = HBApplicationContext(
            threadPool: self.threadPool,
            configuration: self.configuration,
            logger: self.logger,
            encoder: self.encoder,
            decoder: self.decoder
        )
        let dateCache = HBDateCache()
        @Sendable func respond(to request: HBHTTPRequest, channel: Channel) async throws -> HBHTTPResponse {
            let request = HBRequest(
                head: request.head,
                body: request.body
            )
            let context = Responder.Context(
                applicationContext: context,
                channel: channel,
                logger: HBApplication.loggerWithRequestId(context.logger)
            )
            // respond to request
            var response = try await self.responder.respond(to: request, context: context)
            response.headers.add(name: "date", value: dateCache.date)
            // server name header
            if let serverName = self.configuration.serverName {
                response.headers.add(name: "server", value: serverName)
            }
            return HBHTTPResponse(status: response.status, headers: response.headers, body: response.body)
        }
        // update channel with responder
        var channelSetup = self.channelSetup
        channelSetup.responder = respond
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

extension HBApplication: CustomStringConvertible {
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
