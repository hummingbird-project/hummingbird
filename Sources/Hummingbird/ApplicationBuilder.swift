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
    /// Use one of the singleton EventLoopGroups
    case singleton
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
public final class HBApplicationBuilder<RequestContext: HBRequestContext> {
    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public let router: HBRouterBuilder<RequestContext>
    /// Configuration
    public var configuration: HBApplicationConfiguration
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
        requestContext: RequestContext.Type = HBBasicRequestContext.self,
        configuration: HBApplicationConfiguration = HBApplicationConfiguration(),
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.router = HBRouterBuilder(context: RequestContext.self)
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
        case .singleton:
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

    public func build() -> HBApplication<RequestContext> {
        return .init(builder: self)
    }

    /// Helper function that runs application inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGINT, SIGTERM
    public func buildAndRun() async throws {
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [self.build()],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }

    /// middleware applied to requests
    public var middleware: HBMiddlewareGroup<RequestContext> { return self.router.middlewares }

    /// Construct the RequestResponder from the middleware group and router
    func constructResponder() -> any HBResponder<RequestContext> {
        return self.router.buildResponder()
    }

    public func addChannelHandler(_ handler: @autoclosure @escaping @Sendable () -> any RemovableChannelHandler) {
        self.additionalChannelHandlers.append(handler)
    }
}
