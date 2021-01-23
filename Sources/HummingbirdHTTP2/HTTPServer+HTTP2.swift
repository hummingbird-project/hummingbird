import HummingbirdCore
import HummingbirdTLS
import NIO
import NIOHTTP2
import NIOSSL

struct HTTP2ChannelInitializer: HBChannelInitializer {
    init() {}

    func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { () -> EventLoopFuture<Void> in
                server.addChildHandlers(channel: streamChannel, responder: responder)
            }
            .map { _ in }
        }
        .map { _ in }
    }
}

struct HTTP2UpgradeChannelInitializer: HBChannelInitializer {
    let http1 = HTTP1ChannelInitializer()
    let http2 = HTTP2ChannelInitializer()

    init() { }

    func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        channel.configureHTTP2SecureUpgrade(
            h2ChannelConfigurator: { channel in
                http2.initialize(server, channel: channel, responder: responder)
            },
            http1ChannelConfigurator: { channel in
                http1.initialize(server, channel: channel, responder: responder)
            }
        )
    }
}

extension HBHTTPServer {
    @discardableResult public func addHTTP2Upgrade(tlsConfiguration: TLSConfiguration) throws -> HBHTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("h2")
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        
        self.httpChannelInitializer = HTTP2UpgradeChannelInitializer()
        return self.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
    }

    @discardableResult public func setHTTP2() -> HBHTTPServer {
        self.httpChannelInitializer = HTTP2ChannelInitializer()
        return self
    }
}
