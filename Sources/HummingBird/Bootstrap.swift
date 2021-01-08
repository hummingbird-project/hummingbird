import LifecycleNIOCompat
import NIO
import NIOHTTP1

class Bootstrap {
    var channel: Channel?

    init() {}

    func start(group: EventLoopGroup, childHandlers: [ChannelHandler]) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap {
                    channel.pipeline.addHandlers(childHandlers)
                }
        }

        return ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .bind(host: "localhost", port: 8080)
            .map { channel in
                self.channel = channel
            }
    }

    func shutdown(group: EventLoopGroup) -> EventLoopFuture<Void> {
        let promise = group.next().makePromise(of: Void.self)
        if let channel = self.channel {
            channel.close(promise: promise)
        } else {
            return group.next().makeSucceededFuture(())
        }
        return promise.futureResult
    }
}
