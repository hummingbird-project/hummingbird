import NIO
import NIOExtras
import NIOHTTP1

/// HTTP server
public class HBHTTPServer {
    public let eventLoopGroup: EventLoopGroup
    public let configuration: Configuration
    public var httpChannelInitializer: HBChannelInitializer
    public var channel: Channel?

    var quiesce: ServerQuiescingHelper?

    public enum ChannelPosition {
        case beforeHTTP
        case afterHTTP
    }
    
    public struct Configuration {
        public let address: HBBindAddress
        public let reuseAddress: Bool
        public let tcpNoDelay: Bool
        public let withPipeliningAssistance: Bool
        public let maxUploadSize: Int

        public init(
            address: HBBindAddress = .hostname(),
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            withPipeliningAssistance: Bool = false,
            maxUploadSize: Int = 2 * 1024 * 1024
        ) {
            self.address = address
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.withPipeliningAssistance = withPipeliningAssistance
            self.maxUploadSize = maxUploadSize
        }
    }

    public init(group: EventLoopGroup, configuration: Configuration) {
        self.eventLoopGroup = group
        self.configuration = configuration
        self.quiesce = nil
        self._additionalChildHandlers = []
        // defaults to HTTP1
        self.httpChannelInitializer = HTTP1ChannelInitializer()
    }

    /// Append to list of `ChannelHandler`s to be added to server child channels. Need to provide a closure so new instance of these handlers are
    /// created for each child channel
    @discardableResult public func addChildChannelHandler(_ handler: @autoclosure @escaping () -> ChannelHandler, position: ChannelPosition = .afterHTTP) -> Self {
        self._additionalChildHandlers.append((handler: handler, position: position))
        return self
    }

    public func start(responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
            return channel.pipeline.addHandlers(self.additionalChildHandlers(at: .beforeHTTP)).flatMap {
                return self.httpChannelInitializer.initialize(self, channel: channel, responder: responder)
            }
        }
        
        let quiesce = ServerQuiescingHelper(group: self.eventLoopGroup)
        self.quiesce = quiesce
        
        let bootstrap = ServerBootstrap(group: self.eventLoopGroup)
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

        let bindFuture: EventLoopFuture<Void>
        switch configuration.address {
        case .hostname(let host, let port):
            bindFuture = bootstrap.bind(host: host, port: port)
                .map { channel in
                    self.channel = channel
                    responder.logger?.info("Server started and listening on \(host):\(port)")
                }
        case .unixDomainSocket(let path):
            bindFuture = bootstrap.bind(unixDomainSocketPath: path)
                .map { channel in
                    self.channel = channel
                    responder.logger?.info("Server started and listening on socket path \(path)")
                }
        }

        return bindFuture
            .flatMapErrorThrowing { error in
                quiesce.initiateShutdown(promise: nil)
                self.quiesce = nil
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
        return promise.futureResult.map { _ in self.channel = nil }
    }

    public func addChildHandlers(channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        let childHandlers: [ChannelHandler] = self.additionalChildHandlers(at: .afterHTTP) + [
            HBHTTPEncodeHandler(),
            HBHTTPDecodeHandler(configuration: self.configuration),
            HBHTTPServerHandler(responder: responder),
        ]
        return channel.pipeline.addHandlers(childHandlers)
    }

    func additionalChildHandlers(at position: ChannelPosition) -> [ChannelHandler] {
        return self._additionalChildHandlers.compactMap { if $0.position == position { return $0.handler() }; return nil }
    }

    private var _additionalChildHandlers: [(handler: () -> ChannelHandler, position: ChannelPosition)]
}
