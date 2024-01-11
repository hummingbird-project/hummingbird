//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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

public protocol HBApplicationProtocol: Service where Context: HBRequestContext {
    /// Responder that generates a response from a requests and context
    associatedtype Responder: HBResponder
    /// Child Channel setup. This defaults to support HTTP1
    associatedtype ChildChannel: HBChildChannel & HTTPChannelHandler = HTTP1Channel
    /// Context passed with HBRequest to responder
    typealias Context = Responder.Context

    /// Build the responder
    var responder: Responder { get async throws }
    /// Server channel setup
    var server: HBHTTPChannelBuilder<ChildChannel> { get }

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
    /// Array of processes run before we kick off the server. These tend to be processes that need
    /// other services running but need to be run before the server is setup
    var processesRunBeforeServerStart: [@Sendable () async throws -> Void] { get }
}

extension HBApplicationProtocol {
    /// Server channel setup
    public var server: HBHTTPChannelBuilder<HTTP1Channel> { .http1() }
}

extension HBApplicationProtocol {
    /// Default event loop group used by application
    public var eventLoopGroup: EventLoopGroup { MultiThreadedEventLoopGroup.singleton }
    /// Default Configuration
    public var configuration: HBApplicationConfiguration { .init() }
    /// Default Logger
    public var logger: Logger { Logger(label: self.configuration.serverName ?? "HummingBird") }
    /// Default onServerRunning that does nothing
    public func onServerRunning(_: Channel) async {}
    /// Default to no extra services attached to the application.
    public var services: [any Service] { [] }
    /// Default to no processes being run before the server is setup
    public var processesRunBeforeServerStart: [@Sendable () async throws -> Void] { [] }
}

/// Conform to `Service` from `ServiceLifecycle`.
extension HBApplicationProtocol {
    /// Construct application and run it
    public func run() async throws {
        let dateCache = HBDateCache()
        let responder = try await self.responder

        // Function responding to HTTP request
        @Sendable func respond(to request: HBRequest, channel: Channel) async throws -> HBResponse {
            let context = Self.Responder.Context(
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
        let channelSetup = try self.server.build(respond)
        // create server
        let server = HBServer(
            childChannelSetup: channelSetup,
            configuration: self.configuration.httpServer,
            onServerRunning: self.onServerRunning,
            eventLoopGroup: self.eventLoopGroup,
            logger: self.logger
        )
        let serverService = PrecursorService(service: server) {
            for process in self.processesRunBeforeServerStart {
                try await process()
            }
        }
        let services: [any Service] = self.services + [dateCache, serverService]
        let serviceGroup = ServiceGroup(
            configuration: .init(services: services, logger: self.logger)
        )
        try await serviceGroup.run()
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
    return logger.with(metadataKey: "hb_id", value: .stringConvertible(RequestID()))
}

/// Application class. Brings together all the components of Hummingbird together
///
/// ```
/// let router = HBRouter()
/// router.middleware.add(MyMiddleware())
/// router.get("hello") { _ in
///     return "hello"
/// }
/// let app = HBApplication(responder: router.buildResponder())
/// try await app.runService()
/// ```
/// Editing the application setup after calling `runService` will produce undefined behaviour.
public struct HBApplication<Responder: HBResponder, ChildChannel: HBChildChannel & HTTPChannelHandler>: HBApplicationProtocol where Responder.Context: HBRequestContext {
    public typealias Context = Responder.Context
    public typealias ChildChannel = ChildChannel
    public typealias Responder = Responder

    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// routes requests to requestResponders based on URI
    public let responder: Responder
    /// Configuration
    public var configuration: HBApplicationConfiguration
    /// Logger
    public var logger: Logger
    /// on server running
    private var _onServerRunning: @Sendable (Channel) async -> Void
    /// Server channel setup
    public let server: HBHTTPChannelBuilder<ChildChannel>
    /// services attached to the application.
    public var services: [any Service]
    /// Processes to be run before server is started
    public private(set) var processesRunBeforeServerStart: [@Sendable () async throws -> Void]

    // MARK: Initialization

    /// Initialize new Application
    ///
    /// - Parameters:
    ///   - responder: HTTP responder. Returns a response based off a request and context
    ///   - server: Server child channel setup (http1, http2, http1WithWebSocketUpgrade etc)
    ///   - configuration: Application configuration
    ///   - onServerRunning: Function called once the server is running
    ///   - eventLoopGroupProvider: Where to get our EventLoopGroup
    ///   - logger: Logger application uses
    public init(
        responder: Responder,
        server: HBHTTPChannelBuilder<ChildChannel> = .http1(),
        configuration: HBApplicationConfiguration = HBApplicationConfiguration(),
        onServerRunning: @escaping @Sendable (Channel) async -> Void = { _ in },
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
        logger: Logger? = nil
    ) {
        if let logger {
            self.logger = logger
        } else {
            var logger = Logger(label: configuration.serverName ?? "Hummingbird")
            logger.logLevel = HBEnvironment().get("LOG_LEVEL").map { Logger.Level(rawValue: $0) ?? .info } ?? .info
            self.logger = logger
        }
        self.responder = responder
        self.server = server
        self.configuration = configuration
        self._onServerRunning = onServerRunning

        self.eventLoopGroup = eventLoopGroupProvider.eventLoopGroup
        self.services = []
        self.processesRunBeforeServerStart = []
    }

    /// Initialize new Application
    ///
    /// - Parameters:
    ///   - router: Router used to generate responses from requests
    ///   - server: Server child channel setup (http1, http2, http1WithWebSocketUpgrade etc)
    ///   - configuration: Application configuration
    ///   - onServerRunning: Function called once the server is running
    ///   - eventLoopGroupProvider: Where to get our EventLoopGroup
    ///   - logger: Logger application uses
    public init<ResponderBuilder: HBResponderBuilder>(
        router: ResponderBuilder,
        server: HBHTTPChannelBuilder<ChildChannel> = .http1(),
        configuration: HBApplicationConfiguration = HBApplicationConfiguration(),
        onServerRunning: @escaping @Sendable (Channel) async -> Void = { _ in },
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
        logger: Logger? = nil
    ) where Responder == ResponderBuilder.Responder {
        if let logger {
            self.logger = logger
        } else {
            var logger = Logger(label: configuration.serverName ?? "Hummingbird")
            logger.logLevel = HBEnvironment().get("LOG_LEVEL").map { Logger.Level(rawValue: $0) ?? .info } ?? .info
            self.logger = logger
        }
        self.responder = router.buildResponder()
        self.server = server
        self.configuration = configuration
        self._onServerRunning = onServerRunning

        self.eventLoopGroup = eventLoopGroupProvider.eventLoopGroup
        self.services = []
        self.processesRunBeforeServerStart = []
    }

    // MARK: Methods

    ///  Add service to be managed by application ServiceGroup
    /// - Parameter services: list of services to be added
    public mutating func addServices(_ services: any Service...) {
        self.services.append(contentsOf: services)
    }

    /// Add a process to run before we kick off the server service
    ///
    /// This is for processes that might need another Service running but need
    /// to run before the server has started. For example a database migration
    /// process might need the database connection pool running but should be
    /// finished before any request to the server can be made. Also they may be
    /// situations where you want another Service to have fully initialized
    /// before starting the server service.
    ///
    /// - Parameter process: Process to run before server is started
    public mutating func runBeforeServerStart(_ process: @escaping @Sendable () async throws -> Void) {
        self.processesRunBeforeServerStart.append(process)
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
