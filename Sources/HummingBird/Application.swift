import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

public class Application {
    public let lifecycle: ServiceLifecycle
    public let eventLoopGroup: EventLoopGroup
    public let threadPool: NIOThreadPool
    public let logger: Logger
    public let middlewares: MiddlewareGroup
    public let router: BasicRouter
    public var encoder: EncoderProtocol
    public var decoder: DecoderProtocol

    let server: Server
    var responder: RequestResponder?

    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = BasicRouter()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.server = Server()

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
            shutdown: .eventLoopFuture({ self.server.shutdown(group: self.eventLoopGroup) })
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
    
    public func shutdown() throws {
        try self.threadPool.syncShutdownGracefully()
        try self.eventLoopGroup.syncShutdownGracefully()
    }
    
    func constructResponder() -> RequestResponder {
        return self.middlewares.constructResponder(finalResponder: self.router)
    }
}
