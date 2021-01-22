import HummingbirdCore
import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

/// Application class.
open class HBApplication {
    /// server lifecycle, controls initialization and shutdown of application
    public let lifecycle: ServiceLifecycle
    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// middleware applied to requests
    public let middlewares: HBMiddlewareGroup
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

    var responder: HBResponder?

    /// Initialize new Application
    public init(configuration: HBApplication.Configuration = HBApplication.Configuration()) {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HummingBird")
        self.middlewares = HBMiddlewareGroup()
        self.router = TrieRouter()
        self.configuration = configuration
        self.extensions = HBExtensions()
        self.encoder = HBNullEncoder()
        self.decoder = HBNullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.server = HBHTTPServer(group: self.eventLoopGroup, configuration: self.configuration.httpServer)

        self.lifecycle.register(
            label: "Application",
            start: .sync { self.responder = self.constructResponder() },
            shutdown: .sync(self.shutdownApplication)
        )

        self.lifecycle.register(
            label: "HTTP Server",
            start: .eventLoopFuture {
                return self.server.start(responder: HummingbirdResponder(application: self))
            },
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
    func constructResponder() -> HBResponder {
        return self.middlewares.constructResponder(finalResponder: self.router)
    }

    /// shutdown eventloop, threadpool and any extensions attached to the Application
    func shutdownApplication() throws {
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
        self.extensions.shutdown()
    }
}
