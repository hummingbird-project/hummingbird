import LifecycleNIOCompat
import NIO
import NIOHTTP1

class Server {
    var channel: Channel?
    
    init() {}

    func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap {
                    let childHandlers: [ChannelHandler] = [
                        BackPressureHandler(),
                        HTTPInHandler(),
                        HTTPOutHandler(),
                        ServerHandler(application: application),
                    ]
                    return channel.pipeline.addHandlers(childHandlers)
                }
        }

        return ServerBootstrap(group: application.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .bind(host: "localhost", port: application.configuration.port)
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
