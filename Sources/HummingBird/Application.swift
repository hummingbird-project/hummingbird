import Foundation
import Lifecycle
import LifecycleNIOCompat
import Logging
import NIO

public class Application {
    let lifecycle: ServiceLifecycle
    let eventLoopGroup: EventLoopGroup
    let logger: Logger
    let bootstrap: Bootstrap
    public var middlewares: MiddlewareGroup
    public var router: BasicRouter
    public var encoder: EncoderProtocol
    public var decoder: DecoderProtocol

    public init() {
        self.lifecycle = ServiceLifecycle()
        self.logger = Logger(label: "HB")
        self.middlewares = MiddlewareGroup()
        self.router = BasicRouter()
        self.encoder = NullEncoder()
        self.decoder = NullDecoder()

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(
            label: "EventLoopGroup",
            .sync(eventLoopGroup.syncShutdownGracefully)
        )

        self.bootstrap = Bootstrap()
        self.lifecycle.register(
            label: "ServerBootstrap",
            start: .eventLoopFuture({
                let responder = self.middlewares.constructResponder(finalResponder: self.router)
                let httpHandler = HTTPHandler { request, context in
                    let request = Request(
                        path: request.head.uri,
                        method: request.head.method,
                        headers: request.head.headers,
                        body: request.body,
                        application: self,
                        eventLoop: context.eventLoop,
                        allocator: context.channel.allocator
                    )
                    return responder.apply(to: request).map { response in
                        return HTTPHandler.Response(
                            head: .init(version: .init(major: 1, minor: 1), status: .ok, headers: response.headers),
                            body: response.body
                        )
                    }
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
}
