import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

/// Application class.
open class Application {
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
    /// servers
    public var servers: [String: Server]
    /// Logger
    public var logger: Logger
    /// Encoder used by router
    public var encoder: EncoderProtocol
    /// decoder used by router
    public var decoder: DecoderProtocol

    var responder: RequestResponder?

    /// Initialize new Application
    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = BasicRouter()
        self.servers = [:]
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        lifecycle.register(
            label: "Application",
            start: .sync({ self.responder = self.constructResponder() }),
            shutdown: .sync(self.shutdown)
        )
    }

    /// Run application
    public func serve() {
        for (key, value) in servers {
            self.lifecycle.register(
                label: key,
                start: .eventLoopFuture({
                    return value.start(application: self)
                }),
                shutdown: .eventLoopFuture(value.shutdown)
            )
        }
        
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

    public func addServer(_ server: Server, named: String) {
        servers[named] = server
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

extension Application {
    @discardableResult public func addHTTP(_ configuration: HTTPServer.Configuration) -> HTTPServer {
        let server = HTTPServer(
            group: self.eventLoopGroup,
            configuration: .init(port: configuration.port, host: configuration.host)
        )
        addServer(server, named: "HTTP")
        return server
    }
    
    public var http: HTTPServer? { servers["HTTP"] as? HTTPServer }
}
