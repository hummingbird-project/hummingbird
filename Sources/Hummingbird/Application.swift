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

/// Application builder class. Brings together all the components of Hummingbird together
///
/// Setup an HBApplicationBuilder, setup your application middleware, encoders, routes etc and then either
/// add call `build` to create an `HBApplication` which you add to your ServiceLifecycle `ServiceGroup` or
/// run separately with `buildAndRun`.
/// ```
/// let app = HBApplicationBuilder()
/// app.middleware.add(MyMiddleware())
/// app.router.get("hello") { _ in
///     return "hello"
/// }
/// try await app.buildAndRun()
/// ```
/// Editing the application builder setup after calling `build` will produce undefined behaviour.
public struct HBApplication<Responder: HBResponder> {
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
    /// additional channel handlers
    var additionalChannelHandlers: [@Sendable () -> any RemovableChannelHandler]
    /// services attached to the application.
    var services: [any Service]

    // MARK: Initialization

    /// Initialize new Application
    public init(
        responder: Responder,
        configuration: HBApplicationConfiguration = HBApplicationConfiguration(),
        threadPool: NIOThreadPool = .singleton,
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.responder = responder
        self.configuration = configuration
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()
        self.onServerRunning = { _ in }
        // add idle read, write handlers
        if let idleTimeoutConfiguration = configuration.idleTimeoutConfiguration {
            self.additionalChannelHandlers = [{
                IdleStateHandler(
                    readTimeout: idleTimeoutConfiguration.readTimeout,
                    writeTimeout: idleTimeoutConfiguration.writeTimeout
                )
            }]
        } else {
            self.additionalChannelHandlers = []
        }

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

/// Conform to `Service` from `ServiceLifecycle`.
extension HBApplication: Service {
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
            response.headers.add(name: "Date", value: dateCache.date)
            return HBHTTPResponse(status: response.status, headers: response.headers, body: response.body)
        }
        let server = HBServer(
            childChannelSetup: HTTP1Channel(additionalChannelHandlers: self.additionalChannelHandlers.map { $0() }, responder: respond),
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

    public static func loggerWithRequestId(_ logger: Logger) -> Logger {
        let requestId = globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
        return logger.with(metadataKey: "hb_id", value: .stringConvertible(requestId))
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
