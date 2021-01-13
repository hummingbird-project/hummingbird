import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

/// Application class.
open class Application {
    /// configuration
    public let configuration: Configuration
    /// server lifecycle, controls initialization and shutdown of application
    public let lifecycle: ServiceLifecycle
    /// event loop group used by application
    public let eventLoopGroup: EventLoopGroup
    /// thread pool used by application
    public let threadPool: NIOThreadPool
    /// middleware applied to requests
    public let middlewares: MiddlewareGroup
    /// routes requests to requestResponders based on URI
    public var router: Router
    /// Logger
    public var logger: Logger
    /// Encoder used by router
    public var encoder: EncoderProtocol
    /// decoder used by router
    public var decoder: DecoderProtocol
    /// HTTP server
    public var server: HTTPServer

    var responder: RequestResponder?

    /// Initialize new Application
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = BasicRouter()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.server = HTTPServer(
            group: self.eventLoopGroup,
            configuration: .init(port: configuration.port, host: configuration.host)
        )

        lifecycle.registerShutdown(
            label: "Application",
            .sync(self.shutdown)
        )

        self.lifecycle.register(
            label: "ServerBootstrap",
            start: .eventLoopFuture({
                self.responder = self.constructResponder()
                return self.server.start(application: self)
            }),
            shutdown: .eventLoopFuture(self.server.shutdown)
        )
    }

    /// Run application
    public func serve() {
        lifecycle.start { error in
            if let error = error {
                self.logger.error("Failed starting HummingBird: \(error)")
            } else {
                self.logger.info("HummingBird started successfully")
            }
        }
        lifecycle.wait()
    }

    /// Shutdown application
    public func shutdown() {
        lifecycle.shutdown()
    }

    public func addServer(_ server: Server) {

    }
    
    /// Construct the RequestResponder from the middleware group and router
    func constructResponder() -> RequestResponder {
        return self.middlewares.constructResponder(finalResponder: self.router)
    }

    /// shutdown eventloop and threadpool
    func shutdownEventLoopGroup() throws {
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}
