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
    /// Configuration
    public let configuration: HBApplicationConfiguration

    public init(
        configuration: HBApplicationConfiguration
    ) {
        self.configuration = configuration
    }
}

public protocol HBApplicationProtocol: Service {
    /// Context passed with HBRequest to responder
    associatedtype Context: HBRequestContext
    /// Responder that generates a response from a requests and context
    associatedtype Responder: HBResponder<Context>
    /// Child Channel setup. This defaults to support HTTP1
    associatedtype ChannelSetup: HBChannelSetup & HTTPChannelHandler = HTTP1Channel

    /// Build the responder
    func buildResponder() async throws -> Responder
    /// Server channel setup
    func channelSetup(httpResponder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse) throws -> ChannelSetup

    /// event loop group used by application
    var eventLoopGroup: EventLoopGroup { get }
    /// Application configuration
    var configuration: HBApplicationConfiguration { get }
    /// Logger
    var logger: Logger { get }
    /// This is called once the server is running and we have an active Channel
    @Sendable func onServerRunning(_ channel: Channel) async
    /// services attached to the application.
    var services: [any Service] { get }
}

extension HBApplicationProtocol where ChannelSetup == HTTP1Channel {
    /// Defautl channel setup function for HTTP1 channels
    public func channelSetup(httpResponder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse) -> ChannelSetup {
        HTTP1Channel(responder: httpResponder)
    }
}

extension HBApplicationProtocol {
    /// Default event loop group used by application
    public var eventLoopGroup: EventLoopGroup { MultiThreadedEventLoopGroup.singleton }
    /// Default thread pool used by application
    public var threadPool: NIOThreadPool { NIOThreadPool.singleton }
    /// Default Configuration
    public var configuration: HBApplicationConfiguration { .init() }
    /// Default Logger
    public var logger: Logger { Logger(label: self.configuration.serverName ?? "HummingBird") }
    /// Default encoder used by router
    public var encoder: HBResponseEncoder { NullEncoder() }
    /// Default decoder used by router
    public var decoder: HBRequestDecoder { NullDecoder() }
    /// Default onServerRunning that does nothing
    public func onServerRunning(_: Channel) async {}
    /// Default to no extra services attached to the application.
    public var services: [any Service] { [] }
}

/// Conform to `Service` from `ServiceLifecycle`.
extension HBApplicationProtocol {
    /// Construct application and run it
    public func run() async throws {
        let dateCache = HBDateCache()
        let responder = try await self.buildResponder()

        // Function responding to HTTP request
        @Sendable func respond(to request: HBRequest, channel: Channel) async throws -> HBResponse {
            let applicationContext = HBApplicationContext(
                configuration: self.configuration
            )
            let context = Self.Responder.Context(
                applicationContext: applicationContext,
                channel: channel,
                logger: loggerWithRequestId(self.logger)
            )
            // respond to request
            var response = try await responder.respond(to: request, context: context)
            response.headers[.date] = dateCache.date
            // server name header
            if let serverName = self.configuration.serverName {
                response.headers[.server] = serverName
            }
            return response
        }
        // get channel Setup
        let channelSetup = try self.channelSetup(httpResponder: respond)
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

public func loggerWithRequestId(_ logger: Logger) -> Logger {
    let requestId = globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
    return logger.with(metadataKey: "hb_id", value: .stringConvertible(requestId))
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
public struct HBApplication<Responder: HBResponder, ChannelSetup: HBChannelSetup & HTTPChannelHandler>: HBApplicationProtocol where Responder.Context: HBRequestContext {
    public typealias Context = Responder.Context

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
    private var _onServerRunning: @Sendable (Channel) async -> Void
    /// Server channel setup
    let channelSetup: ChannelSetup
    /// services attached to the application.
    public var services: [any Service]

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
        self._onServerRunning = { _ in }

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

    public func buildResponder() async throws -> Responder {
        return self.responder
    }

    public func onServerRunning(_ channel: Channel) async {
        await self._onServerRunning(channel)
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
