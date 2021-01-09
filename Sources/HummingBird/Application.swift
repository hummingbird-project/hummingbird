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

    let bootstrap: Bootstrap

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

        self.bootstrap = Bootstrap()

        lifecycle.registerShutdown(
            label: "Application",
            .sync(self.shutdown)
        )

        self.lifecycle.register(
            label: "ServerBootstrap",
            start: .eventLoopFuture({
                let responder = self.middlewares.constructResponder(finalResponder: self.router)
                let httpHandler = HTTPHandler { request, context in
                    let request = Request(
                        uri: URI(request.head.uri),
                        method: request.head.method,
                        headers: request.head.headers,
                        body: request.body,
                        application: self,
                        eventLoop: context.eventLoop,
                        allocator: context.channel.allocator
                    )
                    return responder.apply(to: request)
                }
                return self.bootstrap.start(group: self.eventLoopGroup, childHandlers: [httpHandler])
            }),
            shutdown: .eventLoopFuture({ self.bootstrap.shutdown(group: self.eventLoopGroup) })
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
}
