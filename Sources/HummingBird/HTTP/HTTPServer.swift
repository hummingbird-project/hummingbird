import NIO
import NIOExtras
import NIOHTTP1

struct HTTPServer {
    let eventLoopGroup: EventLoopGroup
    let quiesce: ServerQuiescingHelper

    init(group: EventLoopGroup) {
        self.eventLoopGroup = group
        self.quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
    }

    func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap {
                    let childHandlers: [ChannelHandler] = application.additionalChildHandlers + [
                        HTTPInHandler(),
                        HTTPOutHandler(),
                        HTTPServerHandler(application: application),
                    ]
                    return channel.pipeline.addHandlers(childHandlers)
                }
        }

        return ServerBootstrap(group: self.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(self.quiesce.makeServerChannelHandler(channel: channel))
            }
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .bind(host: "localhost", port: application.configuration.port)
            .map { _ in }
    }

    func shutdown() -> EventLoopFuture<Void> {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
}
