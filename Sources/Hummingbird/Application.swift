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
import NIOPosix
import NIOTransportServices
import ServiceLifecycle

/// Application class. Brings together all the components of Hummingbird together
///
/// Create an HBApplication, setup your application middleware, encoders, routes etc and then call `start` to
/// start the server and `wait` to wait until the server is stopped.
/// ```
/// let app = HBApplication()
/// app.middleware.add(MyMiddleware())
/// app.get("hello") { _ in
///     return "hello"
/// }
/// app.start()
/// app.wait()
/// ```
/// Editing the application setup after calling `start` will produce undefined behaviour.
public final class HBApplication: HBExtensible, Service, @unchecked Sendable {
    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public let router: HBRouterBuilder
    /// http server
    public let server: HBHTTPServer
    /// Configuration
    public let configuration: Configuration
    /// Application extensions
    public var extensions: HBExtensions<HBApplication>
    /// Logger. Required to be a var by hummingbird-lambda
    public var logger: Logger
    /// Encoder used by router
    public var encoder: HBResponseEncoder
    /// decoder used by router
    public var decoder: HBRequestDecoder
    /// on server running
    let onServerRunning: @Sendable () -> Void

    /// who provided the eventLoopGroup
    let eventLoopGroupProvider: NIOEventLoopGroupProvider

    // MARK: Initialization

    /// Initialize new Application
    public init(
        configuration: HBApplication.Configuration = HBApplication.Configuration(),
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew,
        onServerRunning: @escaping @Sendable () -> Void = {}
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.router = HBRouterBuilder()
        self.configuration = configuration
        self.extensions = HBExtensions()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()
        self.onServerRunning = onServerRunning

        // create eventLoopGroup
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .createNew:
            #if os(iOS)
            self.eventLoopGroup = NIOTSEventLoopGroup()
            #else
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            #endif
        case .shared(let elg):
            self.eventLoopGroup = elg
        }

        self.threadPool = NIOThreadPool(numberOfThreads: configuration.threadPoolSize)
        self.threadPool.start()

        self.server = HBHTTPServer(group: self.eventLoopGroup, configuration: self.configuration.httpServer)

        // register application shutdown with lifecycle
        /* lifecycleTasksContainer.registerShutdown(
             label: "Application", .sync(self.shutdownApplication)
         )

         // register server startup and shutdown with lifecycle
         if !configuration.noHTTPServer {
             lifecycleTasksContainer.register(
                 label: "HTTP Server",
                 start: .eventLoopFuture { self.server.start(responder: HTTPResponder(application: self)) },
                 shutdown: .eventLoopFuture(self.server.stop)
             )
         } */
    }

    // MARK: Methods

    public func run() async throws {
        try await withGracefulShutdownHandler {
            try await self.server.start(responder: HTTPResponder(application: self)).get()
            self.onServerRunning()
            try await withCheckedThrowingContinuation { cont in
                self.server.channel?.closeFuture.whenComplete { result in
                    cont.resume(with: result)
                }
            }
            try await HBDateCache.shutdownDateCaches(eventLoopGroup: self.eventLoopGroup).get()
            try self.shutdownApplication()
        } onGracefulShutdown: {
            _ = self.server.stop()
        }
    }

    public func runService() async throws {
        let serviceGroup = ServiceGroup(
            services: [self],
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
        try self.extensions.shutdown()
        try self.threadPool.syncShutdownGracefully()
        if case .createNew = self.eventLoopGroupProvider {
            try self.eventLoopGroup.syncShutdownGracefully()
        }
    }
}
