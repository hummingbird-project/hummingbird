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

import Dispatch
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle

/// Where should the application get its EventLoopGroup from
public enum EventLoopGroupProvider {
    /// Use this EventLoopGroup
    case shared(EventLoopGroup)
    /// Use one of the global EventLoopGroups
    case global
}

/// Application class. Brings together all the components of Hummingbird together
///
/// Create an HBApplication, setup your application middleware, encoders, routes etc and then either
/// add to ServiceLifecycle `ServiceGroup` or run independently with `runService`.
/// ```
/// let app = HBApplication()
/// app.middleware.add(MyMiddleware())
/// app.router.get("hello") { _ in
///     return "hello"
/// }
/// try await app.runService()
/// ```
/// Editing the application setup after calling `run` will produce undefined behaviour.
public final class HBApplicationBuilder {
    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public let router: HBRouterBuilder
    /// Configuration
    public let configuration: HBApplication.Configuration
    /// Logger. Required to be a var by hummingbird-lambda
    public var logger: Logger
    /// Encoder used by router
    public var encoder: HBResponseEncoder
    /// decoder used by router
    public var decoder: HBRequestDecoder
    /// on server running
    public var onServerRunning: @Sendable (Channel) async -> Void
    /// additional channel handlers
    var additionalChannelHandlers: [@Sendable () -> any RemovableChannelHandler]

    // MARK: Initialization

    /// Initialize new Application
    public init(
        configuration: HBApplication.Configuration = HBApplication.Configuration(),
        eventLoopGroupProvider: EventLoopGroupProvider = .global
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.router = HBRouterBuilder()
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

        // create eventLoopGroup
        switch eventLoopGroupProvider {
        case .global:
            #if os(iOS)
            self.eventLoopGroup = NIOTSEventLoopGroup.singleton
            #else
            self.eventLoopGroup = MultiThreadedEventLoopGroup.singleton
            #endif
        case .shared(let elg):
            self.eventLoopGroup = elg
        }

        self.threadPool = NIOThreadPool(numberOfThreads: configuration.threadPoolSize)
        self.threadPool.start()
    }

    // MARK: Methods

    __consuming public func build() -> HBApplication {
        return .init(builder: self)
    }

    /// Helper function that runs application inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGINT, SIGTERM
    public func buildAndRun() async throws {
        let serviceGroup = ServiceGroup(
            services: [self.build()],
            configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
            logger: self.logger
        )
        try await serviceGroup.run()
    }

    /// middleware applied to requests
    public var middleware: HBMiddlewareGroup { return self.router.middlewares }

    /// Construct the RequestResponder from the middleware group and router
    public func constructResponder() -> HBResponder {
        return self.router.buildRouter()
    }

    /// shutdown eventloop, threadpool and any extensions attached to the Application
    public func shutdownApplication() throws {
        try self.threadPool.syncShutdownGracefully()
    }

    public func addChannelHandler(_ handler: @autoclosure @escaping @Sendable () -> any RemovableChannelHandler) {
        self.additionalChannelHandlers.append(handler)
    }
}

public struct HBApplication: Sendable {
    public struct Context: Sendable {
        /// event loop group used by application
        public let eventLoopGroup: EventLoopGroup
        /// thread pool used by application
        public let threadPool: NIOThreadPool
        /// Configuration
        public let configuration: Configuration
        /// Logger. Required to be a var by hummingbird-lambda
        public let logger: Logger
        /// Encoder used by router
        public let encoder: HBResponseEncoder
        /// decoder used by router
        public let decoder: HBRequestDecoder

        public init(
            eventLoopGroup: EventLoopGroup,
            threadPool: NIOThreadPool,
            configuration: Configuration,
            logger: Logger,
            encoder: HBResponseEncoder,
            decoder: HBRequestDecoder
        ) {
            self.eventLoopGroup = eventLoopGroup
            self.threadPool = threadPool
            self.configuration = configuration
            self.logger = logger
            self.encoder = encoder
            self.decoder = decoder
        }
    }

    /// event loop group used by application
    public let context: Context
    // server
    public let server: HBHTTPServer

    init(builder: HBApplicationBuilder) {
        self.context = .init(
            eventLoopGroup: builder.eventLoopGroup,
            threadPool: builder.threadPool,
            configuration: builder.configuration,
            logger: builder.logger,
            encoder: builder.encoder,
            decoder: builder.decoder
        )
        self.server = HBHTTPServer(
            group: builder.eventLoopGroup,
            configuration: builder.configuration.httpServer,
            responder: Responder(responder: builder.constructResponder(), applicationContext: self.context),
            additionalChannelHandlers: builder.additionalChannelHandlers.map { $0() },
            onServerRunning: builder.onServerRunning,
            logger: builder.logger
        )
    }

    /// shutdown eventloop, threadpool and any extensions attached to the Application
    public func shutdownApplication() throws {
        try self.context.threadPool.syncShutdownGracefully()
    }
}

/// Conform to `Service` from `ServiceLifecycle`.
/// TODO: Temporarily I have added unchecked Sendable conformance to the class as Sendable
/// conformance is required by `Service`. I will need to revisit this.
extension HBApplication: Service {
    public func run() async throws {
        try await withGracefulShutdownHandler {
            try await self.server.run()
            try await HBDateCache.shutdownDateCaches(eventLoopGroup: self.context.eventLoopGroup).get()
            try self.shutdownApplication()
        } onGracefulShutdown: {
            Task {
                try await self.server.shutdownGracefully()
            }
        }
    }
}
