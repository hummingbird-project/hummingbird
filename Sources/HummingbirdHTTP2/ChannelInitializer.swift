import HummingbirdCore
import NIO
import NIOHTTP2
import NIOSSL

/// HTTP2 channel initializer
struct HTTP2ChannelInitializer: HBChannelInitializer {
    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { () -> EventLoopFuture<Void> in
                channel.pipeline.addHandlers(childHandlers)
            }
            .map { _ in }
        }
        .map { _ in }
    }
}

/// HTTP2 upgrade channel initializer
struct HTTP2UpgradeChannelInitializer: HBChannelInitializer {
    let http1 = HTTP1ChannelInitializer()
    let http2 = HTTP2ChannelInitializer()

    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        channel.configureHTTP2SecureUpgrade(
            h2ChannelConfigurator: { channel in
                channel.pipeline.addHandlers(childHandlers)
            },
            http1ChannelConfigurator: { channel in
                channel.pipeline.addHandlers(childHandlers)
            }
        )
    }
}
