import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

public class Application {
    let lifecycle: ServiceLifecycle
    let eventLoopGroup: EventLoopGroup
    let logger: Logger
    let bootstrap: Bootstrap

    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")

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
        let body = context.channel.allocator.buffer(string: "Hello from Hummingbird!")
        let response = HTTPHandler.Response(
            head: .init(version: .init(major: 1, minor: 1), status: .internalServerError ),
            body: body
        )
        return context.eventLoop.makeSucceededFuture(response)
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
}
