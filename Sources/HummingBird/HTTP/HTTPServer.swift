import NIO
import NIOExtras
import NIOHTTP1

public class HTTPServer: Server {
    public let eventLoopGroup: EventLoopGroup
    public let configuration: Configuration

    var quiesce: ServerQuiescingHelper?

    public enum ChannelPosition {
        case beforeHTTP
        case afterHTTP
    }
    
    public struct Configuration {
        public let port: Int
        public let host: String
        public let reuseAddress: Bool
        public let tcpNoDelay: Bool
        public let withPipeliningAssistance: Bool

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            withPipeliningAssistance: Bool = false
        ) {
            self.host = host
            self.port = port
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.withPipeliningAssistance = withPipeliningAssistance
        }
    }

    public init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = nil
        self._additionalChildHandlers = []
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels
    @discardableResult public func addChildChannelHandler(_ handler: @autoclosure @escaping () -> ChannelHandler, position: ChannelPosition = .afterHTTP) -> Self {
        self._additionalChildHandlers.append((handler: handler, position: position))
        return self
    }

    public func start(application: Application) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.addHandlers(self.additionalChildHandlers(at: .beforeHTTP)).flatMap {
                return channel.pipeline.configureHTTPServerPipeline(
                    withPipeliningAssistance: self.configuration.withPipeliningAssistance,
                    withErrorHandling: true
                ).flatMap {
                    let childHandlers: [ChannelHandler] = self.additionalChildHandlers(at: .afterHTTP) + [
                        HTTPOutHandler(),
                        HTTPInHandler(),
                        HTTPServerHandler(application: application),
                    ]
                    return channel.pipeline.addHandlers(childHandlers)
                }
            }
        }
        
        let quiesce = ServerQuiescingHelper(group: application.eventLoopGroup)
        self.quiesce = quiesce
        
        return ServerBootstrap(group: self.eventLoopGroup)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .serverChannelInitializer { channel in
                channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
            }
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer(childChannelInitializer)

            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: configuration.tcpNoDelay ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .bind(host: self.configuration.host, port: self.configuration.port)
            .map { _ in
                application.logger.info("Server started and listening on \(self.configuration.host):\(self.configuration.port)")
            }
            .flatMapErrorThrowing { error in
                _ = self.stop()
                throw error
            }
    }

    public func stop() -> EventLoopFuture<Void> {
        let promise = self.eventLoopGroup.next().makePromise(of: Void.self)
        if let quiesce = self.quiesce {
            quiesce.initiateShutdown(promise: promise)
            self.quiesce = nil
        } else {
            promise.succeed(())
        }
        return promise.futureResult
    }

    func additionalChildHandlers(at position: ChannelPosition) -> [ChannelHandler] {
        return self._additionalChildHandlers.compactMap { if $0.position == position { return $0.handler() }; return nil }
    }

    private var _additionalChildHandlers: [(handler: () -> ChannelHandler, position: ChannelPosition)]
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
