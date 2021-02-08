import NIO

/// HTTPServer child channel initializer protocol
public protocol HBChannelInitializer {
    func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void>
}

/// Setup child channel for HTTP1
public struct HTTP1ChannelInitializer: HBChannelInitializer {
    public init() {}

    public func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(
            withPipeliningAssistance: server.configuration.withPipeliningAssistance,
            withErrorHandling: true
        ).flatMap {
            return server.addChildHandlers(channel: channel, responder: responder)
        }
    }
}
