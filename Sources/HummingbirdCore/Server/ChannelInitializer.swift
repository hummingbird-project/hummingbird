import NIO
import NIOHTTP1

/// HTTPServer child channel initializer protocol
public protocol HBChannelInitializer {
    /// Initialize channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void>
}

/// Setup child channel for HTTP1
public struct HTTP1ChannelInitializer: HBChannelInitializer {
    public init(upgraders: [HTTPServerProtocolUpgrader] = []) {
        self.upgraders = upgraders
    }

    /// Initialize HTTP1 channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    public func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        var serverUpgrade: NIOHTTPServerUpgradeConfiguration?
        if self.upgraders.count > 0 {
            serverUpgrade = (self.upgraders, { channel in
                // remove HTTP handlers after upgrade
                childHandlers.forEach {
                    _ = channel.pipeline.removeHandler($0)
                }
            })
        }
        return channel.pipeline.configureHTTPServerPipeline(
            withPipeliningAssistance: configuration.withPipeliningAssistance,
            withServerUpgrade: serverUpgrade,
            withErrorHandling: true
        ).flatMap {
            return channel.pipeline.addHandlers(childHandlers)
        }
    }

    let upgraders: [HTTPServerProtocolUpgrader]
}
