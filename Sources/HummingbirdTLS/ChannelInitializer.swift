import HummingbirdCore
import NIOCore
import NIOHTTP1
import NIOSSL

/// Setup child channel for HTTP1 with TLS
public struct HTTP1WithTLSChannel: HBChannelInitializer {
    public init(tlsConfiguration: TLSConfiguration, upgraders: [HTTPServerProtocolUpgrader] = []) throws {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("http/1.1")
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
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
            let loopBoundChildHandlers = NIOLoopBound(childHandlers, eventLoop: channel.eventLoop)
            serverUpgrade = (self.upgraders, { channel in
                // remove HTTP handlers after upgrade
                loopBoundChildHandlers.value.forEach {
                    _ = channel.pipeline.removeHandler($0)
                }
            })
        }
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: self.sslContext))
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: configuration.withPipeliningAssistance,
                withServerUpgrade: serverUpgrade,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childHandlers)
        }
    }

    ///  Add protocol upgrader to channel initializer
    /// - Parameter upgrader: HTTP server protocol upgrader to add
    public mutating func addProtocolUpgrader(_ upgrader: HTTPServerProtocolUpgrader) {
        self.upgraders.append(upgrader)
    }

    let sslContext: NIOSSLContext
    var upgraders: [HTTPServerProtocolUpgrader]
}
