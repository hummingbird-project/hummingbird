import NIO
import NIOExtras
import NIOHTTP1

public struct HTTPServer {
    let eventLoopGroup: EventLoopGroup
    let configuration: Configuration
    let quiesce: ServerQuiescingHelper
    var additionalChildHandlers: [ ()->ChannelHandler ]

    struct Configuration {
        let port: Int
        let host: String
    }

    init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        self.additionalChildHandlers = []
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels
    public mutating func addChildChannelHandler(_ handler: @autoclosure @escaping ()->ChannelHandler) {
        additionalChildHandlers.append(handler)
    }

    func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap {
                    let childHandlers: [ChannelHandler] = additionalChildHandlers.map { $0() } + [
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
            .bind(host: configuration.host, port: configuration.port)
            .map { _ in }
            .flatMapErrorThrowing { error in
                quiesce.initiateShutdown(promise: nil)
                throw error
            }
    }

    func shutdown() -> EventLoopFuture<Void> {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }
}
