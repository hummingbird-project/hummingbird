import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

public class Application {
    let lifecycle: ServiceLifecycle
    let eventLoopGroup: EventLoopGroup
    let logger: Logger
    let bootstrap: Bootstrap
    public var middlewares: Middlewares
    var responder: MiddlewaresResponder?
    public var router: BasicRouter

    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = Middlewares()
        self.router = BasicRouter()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(
            label: "EventLoopGroup",
            .sync(eventLoopGroup.syncShutdownGracefully)
        )

        self.bootstrap = Bootstrap()
        self.lifecycle.register(
            label: "ServerBootstrap",
            start: .eventLoopFuture({
                self.bootstrap.start(group: self.eventLoopGroup, childHandlers: [HTTPHandler(self.route)])
            }),
            shutdown: .eventLoopFuture({ self.bootstrap.shutdown(group: self.eventLoopGroup) })
        )
    }

    func route(_ request: HTTPHandler.Request, context: ChannelHandlerContext) -> EventLoopFuture<HTTPHandler.Response> {
        let request = Request(
            path: request.head.uri,
            method: request.head.method,
            headers: request.head.headers,
            body: request.body,
            eventLoop: context.eventLoop,
            allocator: context.channel.allocator
        )
        return responder!.apply(to: request).map { response in
            return HTTPHandler.Response(
                head: .init(version: .init(major: 1, minor: 1), status: .ok, headers: response.headers),
                body: response.body
            )
        }
    }

    public func serve() {
        self.responder = MiddlewaresResponder(middlewares: self.middlewares, finalResponder: router)
        lifecycle.start { error in
            if let error = error {
                self.logger.error("Failed starting HummingBird: \(error)")
            } else {
                self.logger.info("HummingBird started successfully")
            }
        }
        lifecycle.wait()
    }
}
