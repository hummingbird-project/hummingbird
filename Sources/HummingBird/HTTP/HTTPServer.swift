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
        public let reuseAddress: Bool
        public let tcpNoDelay: Bool
        public let enableHTTPPipelining: Bool

        public init(
            host: String = "localhost",
            port: Int = 8080,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = true,
            enableHTTPPipelining: Bool = false
        ) {
            self.host = host
            self.port = port
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.enableHTTPPipelining = enableHTTPPipelining
        }
    }

    public init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        self._additionalChildHandlers = []
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels
    public func addChildChannelHandler(_ handler: @autoclosure @escaping () -> ChannelHandler, position: ChannelPipeline.Position = .last) {
        self._additionalChildHandlers.append((handler: handler, position: position))
    }

    public func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.addHandlers(self.additionalChildHandlers(at: .first)).flatMap {
                return channel.pipeline.configureHTTPServerPipeline(
                    withPipeliningAssistance: self.configuration.enableHTTPPipelining,
                    withErrorHandling: true
                ).flatMap {
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
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(self.quiesce.makeServerChannelHandler(channel: channel))
            }
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: configuration.tcpNoDelay ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .bind(host: self.configuration.host, port: self.configuration.port)
            .map { _ in }
            .flatMapErrorThrowing { error in
                self.quiesce.initiateShutdown(promise: nil)
                throw error
            }
    }

    public func shutdown() -> EventLoopFuture<Void> {
        let promise = self.eventLoopGroup.next().makePromise(of: Void.self)
        self.quiesce.initiateShutdown(promise: promise)
        return promise.futureResult
    }

    func additionalChildHandlers(at position: ChannelPipeline.Position) -> [ChannelHandler] {
        return self._additionalChildHandlers.compactMap { if $0.position == position { return $0.handler() }; return nil }
    }

    private var _additionalChildHandlers: [(handler: () -> ChannelHandler, position: ChannelPipeline.Position)]
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
