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
/// Editing the application setup after calling `run` will produce undefined behaviour.
public final class HBApplication: HBExtensible {
    // MARK: Member variables

    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public let router: HBRouterBuilder
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
    var onServerRunning: @Sendable (Channel) async -> Void
    /// additional channel handlers
    var additionalChannelHandlers: [@Sendable () -> any RemovableChannelHandler]
    /// who provided the eventLoopGroup
    let eventLoopGroupProvider: NIOEventLoopGroupProvider

    // MARK: Initialization

    /// Initialize new Application
    public init(
        configuration: HBApplication.Configuration = HBApplication.Configuration(),
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew,
        onServerRunning: @escaping @Sendable (Channel) async -> Void = { _ in }
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
    }

    // MARK: Methods

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

    public func addChannelHandler(_ handler: @autoclosure @escaping @Sendable () -> any RemovableChannelHandler) {
        self.additionalChannelHandlers.append(handler)
    }
}

/// Conform to `Service` from `ServiceLifecycle`.
/// TODO: Temporarily I have added unchecked Sendable conformance to the class as Sendable
/// conformance is required by `Service`. I will need to revisit this.
extension HBApplication: Service, @unchecked Sendable {
    public func run() async throws {
        let server = HBHTTPServer(
            group: self.eventLoopGroup,
            configuration: self.configuration.httpServer,
            responder: HTTPResponder(application: self),
            additionalChannelHandlers: self.additionalChannelHandlers.map { $0() },
            onServerRunning: self.onServerRunning,
            logger: self.logger
        )
        try await withGracefulShutdownHandler {
            try await server.run()
            try await HBDateCache.shutdownDateCaches(eventLoopGroup: self.eventLoopGroup).get()
            try self.shutdownApplication()
        } onGracefulShutdown: {
            Task {
                try await server.shutdownGracefully()
            }
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
}
