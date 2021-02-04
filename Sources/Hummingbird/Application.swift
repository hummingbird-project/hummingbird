import HummingbirdCore
import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

/// Application class.
public final class HBApplication: HBExtensible {
    /// server lifecycle, controls initialization and shutdown of application
    public let lifecycle: ServiceLifecycle
    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// middleware applied to requests
    public let middleware: HBMiddlewareGroup
    /// routes requests to requestResponders based on URI
    public var router: HBRouter
    /// http server
    public var server: HBHTTPServer
    /// Configuration
    public var configuration: Configuration
    /// Application extensions
    public var extensions: HBExtensions<HBApplication>
    /// Logger
    public var logger: Logger
    /// Encoder used by router
    public var encoder: HBResponseEncoder
    /// decoder used by router
    public var decoder: HBRequestDecoder

    /// who provided the eventLoopGroup
    let eventLoopGroupProvider: NIOEventLoopGroupProvider

    /// Initialize new Application
    public init(configuration: HBApplication.Configuration = HBApplication.Configuration(), eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew) {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HummingBird")
        self.middleware = HBMiddlewareGroup()
        self.router = TrieRouter()
        self.configuration = configuration
        self.extensions = HBExtensions()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        case .shared(let elg):
            self.eventLoopGroup = elg
        }
        self.threadPool = NIOThreadPool(numberOfThreads: configuration.threadPoolSize)
        self.threadPool.start()

        self.server = HBHTTPServer(group: self.eventLoopGroup, configuration: self.configuration.httpServer)

        self.addEventLoopStorage()

        self.lifecycle.registerShutdown(
            label: "Application", .sync(self.shutdownApplication)
        )

        self.lifecycle.register(
            label: "HTTP Server",
            start: .eventLoopFuture { self.server.start(responder: HTTPResponder(application: self)) },
            shutdown: .eventLoopFuture(self.server.stop)
        )
    }

    /// Run application
    public func start() {
        self.lifecycle.start { error in
            if let error = error {
                self.logger.error("Failed starting HummingBird: \(error)")
            } else {
                self.logger.info("HummingBird started successfully")
            }
        }
    }

    /// wait while server is running
    public func wait() {
        self.lifecycle.wait()
    }

    /// Shutdown application
    public func stop() {
        self.lifecycle.shutdown()
    }

    /// Construct the RequestResponder from the middleware group and router
    public func constructResponder() -> HBResponder {
        return self.middleware.constructResponder(finalResponder: self.router)
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
