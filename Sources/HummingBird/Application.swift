import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

open class Application {
    public let configuration: Configuration
    public let lifecycle: ServiceLifecycle
    public let eventLoopGroup: EventLoopGroup
    public let threadPool: NIOThreadPool
    public let middlewares: MiddlewareGroup
    public var router: BasicRouter
    public var logger: Logger
    public var encoder: EncoderProtocol
    public var decoder: DecoderProtocol
    public var additionalChildHandlers: [ChannelHandler]

    let server: HTTPServer
    var responder: RequestResponder?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = BasicRouter()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()
        self.additionalChildHandlers = []

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.server = HTTPServer(group: self.eventLoopGroup)

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

    public func syncShutdown() {
        lifecycle.shutdown()
        lifecycle.wait()
    }

    public func shutdown() {
        lifecycle.shutdown()
    }

    func constructResponder() -> RequestResponder {
        return self.middlewares.constructResponder(finalResponder: self.router)
    }

    func shutdownEventLoopGroup() throws {
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
}
