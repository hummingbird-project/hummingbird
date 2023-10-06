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
import Lifecycle
import LifecycleNIOCompat
import Logging
import NIOCore
import NIOPosix
import NIOTransportServices

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
public final class HBApplication: HBExtensible {
    /// Indicates where we should get our EventLoopGroup from
    public struct EventLoopGroupProvider {
        enum Internal {
            case createNew
            case shared(EventLoopGroup)
            case singleton
        }

        let value: Internal
        init(_ value: Internal) {
            self.value = value
        }

        /// Use EventLoopGroup provided
        public static func shared(_ eventLoopGroup: EventLoopGroup) -> Self { .init(.shared(eventLoopGroup)) }
        /// Use singleton EventLoopGroup
        public static var singleton: Self { .init(.singleton) }
    }

    // MARK: Member variables

    /// server lifecycle, controls initialization and shutdown of application
    public let lifecycle: ServiceLifecycle
    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// routes requests to requestResponders based on URI
    public var router: HBRouterBuilder
    /// http server
    public var server: HBHTTPServer
    /// Configuration
    public var configuration: Configuration
    /// Application extensions
    public var extensions: HBExtensions<HBApplication>
    /// Logger. Required to be a var by hummingbird-lambda
    public var logger: Logger
    /// Encoder used by router
    public var encoder: HBResponseEncoder
    /// decoder used by router
    public var decoder: HBRequestDecoder

    /// who provided the eventLoopGroup
    let eventLoopGroupProvider: HBApplication.EventLoopGroupProvider

    // MARK: Initialization

    /// Initialize new Application
    public init(
        configuration: HBApplication.Configuration = HBApplication.Configuration(),
        eventLoopGroupProvider: EventLoopGroupProvider = .singleton,
        serviceLifecycleProvider: ServiceLifecycleProvider = .createNew
    ) {
        var logger = Logger(label: configuration.serverName ?? "HummingBird")
        logger.logLevel = configuration.logLevel
        self.logger = logger

        self.router = HBRouterBuilder()
        self.configuration = configuration
        self.extensions = HBExtensions()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        // create eventLoopGroup
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch self.eventLoopGroupProvider.value {
        case .createNew:
            #if os(iOS)
            self.eventLoopGroup = NIOTSEventLoopGroup()
            #else
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            #endif
        case .singleton:
            #if os(iOS)
            self.eventLoopGroup = NIOTSEventLoopGroup.singleton
            #else
            self.eventLoopGroup = MultiThreadedEventLoopGroup.singleton
            #endif
        case .shared(let elg):
            self.eventLoopGroup = elg
        }

        // create lifecycle
        let lifecycleTasksContainer: LifecycleTasksContainer

        switch serviceLifecycleProvider {
        case .shared(let parentLifecycle):
            self.lifecycle = parentLifecycle
            let componentLifecycle = ComponentLifecycle(label: self.logger.label, logger: self.logger)
            lifecycleTasksContainer = componentLifecycle
            self.lifecycle.register(componentLifecycle)
        case .createNew:
            let serviceLifecycle = ServiceLifecycle(configuration: .init(logger: self.logger))
            lifecycleTasksContainer = serviceLifecycle
            self.lifecycle = serviceLifecycle
        }

        self.threadPool = NIOThreadPool(numberOfThreads: configuration.threadPoolSize)
        self.threadPool.start()

        self.server = HBHTTPServer(group: self.eventLoopGroup, configuration: self.configuration.httpServer)

        // register application shutdown with lifecycle
        lifecycleTasksContainer.registerShutdown(
            label: "Application", .sync(self.shutdownApplication)
        )

        lifecycleTasksContainer.registerShutdown(
            label: "DateCache", .eventLoopFuture { HBDateCache.shutdownDateCaches(eventLoopGroup: self.eventLoopGroup) }
        )

        // register server startup and shutdown with lifecycle
        if !configuration.noHTTPServer {
            lifecycleTasksContainer.register(
                label: "HTTP Server",
                start: .eventLoopFuture { self.server.start(responder: HTTPResponder(application: self)) },
                shutdown: .eventLoopFuture(self.server.stop)
            )
        }
    }

    @available(*, deprecated, message: "Calling HBApplication.init(eventLoopGroupProvider: .createNew) has been deprecated. Use .singleton instead.")
    @_disfavoredOverload
    public convenience init(
        configuration: HBApplication.Configuration = HBApplication.Configuration(),
        eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew,
        serviceLifecycleProvider: ServiceLifecycleProvider = .createNew
    ) {
        switch eventLoopGroupProvider {
        case .createNew:
            self.init(configuration: configuration, eventLoopGroupProvider: .init(.createNew), serviceLifecycleProvider: serviceLifecycleProvider)
        case .shared(let elg):
            self.init(configuration: configuration, eventLoopGroupProvider: .init(.shared(elg)), serviceLifecycleProvider: serviceLifecycleProvider)
        }
    }

    // MARK: Methods

    /// Start application and wait for it to stop
    ///
    /// This function can only be called from a non async context as it stalls
    /// the current thread waiting for the application to finish
    @available(*, noasync, message: "Use HBApplication.asyncRun instead.")
    public func run() throws {
        try self.start()
        self.wait()
    }

    /// Start application and wait for it to stop
    ///
    /// Version of `run`` that can be called from asynchronous context
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func asyncRun() async throws {
        try await self.onExecutionQueue { app in
            try app.start()
            app.wait()
        }
    }

    /// Start application
    public func start() throws {
        var startError: Error?
        let startSemaphore = DispatchSemaphore(value: 0)

        self.lifecycle.start { error in
            startError = error
            startSemaphore.signal()
        }
        startSemaphore.wait()
        try startError.map { throw $0 }
    }

    /// Wait until server has stopped running
    ///
    /// This function can only be called from a non async context as it stalls
    /// the current thread waiting for the application to finish
    @available(*, noasync, message: "Use HBApplication.asyncRun instead.")
    public func wait() {
        self.lifecycle.wait()
    }

    /// Wait until server has stopped running
    ///
    /// Version of `wait`` that can be called from asynchronous context
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func asyncWait() async {
        await self.onExecutionQueue { app in
            app.wait()
        }
    }

    /// Shutdown application
    public func stop() {
        let stopSemaphore = DispatchSemaphore(value: 0)

        self.lifecycle.shutdown { _ in
            stopSemaphore.signal()
        }
        stopSemaphore.wait()
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
        if case .createNew = self.eventLoopGroupProvider.value {
            try self.eventLoopGroup.syncShutdownGracefully()
        }
    }

    /// Run throwing closure on private execution queue
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private func onExecutionQueue(_ process: @Sendable @escaping (HBApplication) throws -> Void) async throws {
        let unsafeApp = HBUnsafeTransfer(self)
        try await withCheckedThrowingContinuation { continuation in
            HBApplication.executionQueue.async {
                do {
                    try process(unsafeApp.wrappedValue)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Run closure on private execution queue
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    private func onExecutionQueue(_ process: @Sendable @escaping (HBApplication) -> Void) async {
        let unsafeApp = HBUnsafeTransfer(self)
        await withCheckedContinuation { continuation in
            HBApplication.executionQueue.async {
                process(unsafeApp.wrappedValue)
                continuation.resume()
            }
        }
    }

    private static let executionQueue = DispatchQueue(label: "hummingbird.execution")
}
