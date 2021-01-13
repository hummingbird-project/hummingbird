import NIO
import NIOExtras
import NIOHTTP1

public class HTTPServer: Server {
    
    public let eventLoopGroup: EventLoopGroup
    public let configuration: Configuration
    
    let quiesce: ServerQuiescingHelper

    public struct Configuration {        
        public let port: Int
        public let host: String

        public init(port: Int, host: String) {
            self.port = port
            self.host = host
        }
    }

    public init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        self._additionalChildHandlers = []
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels
    public func addChildChannelHandler(_ handler: @autoclosure @escaping ()->ChannelHandler, position: ChannelPipeline.Position = .last) {
        _additionalChildHandlers.append((handler: handler, position: position))
    }

    public func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.addHandlers(additionalChildHandlers(at: .first)).flatMap {
                return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                    .flatMap {
                        let childHandlers: [ChannelHandler] = self.additionalChildHandlers(at: .last) + [
                            HTTPInHandler(),
                            HTTPOutHandler(),
                            HTTPServerHandler(application: application),
                        ]
                        return channel.pipeline.addHandlers(childHandlers)
                    }
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
                self.quiesce.initiateShutdown(promise: nil)
                throw error
            }
    }

    public func shutdown() -> EventLoopFuture<Void> {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }

    func additionalChildHandlers(at position: ChannelPipeline.Position) -> [ChannelHandler] {
        return _additionalChildHandlers.compactMap { if $0.position == position { return $0.handler() }; return nil }
    }

    private var _additionalChildHandlers: [ (handler: ()->ChannelHandler, position: ChannelPipeline.Position) ]
}

extension ChannelPipeline.Position: Equatable {
    public static func == (lhs: ChannelPipeline.Position, rhs: ChannelPipeline.Position) -> Bool {
        switch (lhs, rhs) {
        case (.first, .first), (.last, .last):
            return true
        default:
            return false
        }
    }
}
