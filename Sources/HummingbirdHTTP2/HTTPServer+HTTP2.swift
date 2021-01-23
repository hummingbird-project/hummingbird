import HummingbirdCore
import HummingbirdTLS
import NIO
import NIOHTTP2
import NIOSSL

final class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Server received error: \(error)")
        context.close(promise: nil)
    }
}

struct HTTP2ChannelInitializer: HBChannelInitializer {
    init() {}

    func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { () -> EventLoopFuture<Void> in
                server.addChildHandlers(channel: streamChannel, responder: responder)
            }.flatMap { () -> EventLoopFuture<Void> in
                streamChannel.pipeline.addHandler(ErrorHandler())
            }
        }.flatMap { (_: HTTP2StreamMultiplexer) in
            return channel.pipeline.addHandler(ErrorHandler())
        }
    }
}

struct HTTP2UpgradeChannelInitializer: HBChannelInitializer {
    let http1: HTTP1ChannelInitializer
    
    init() {
        self.http1 = .init()
    }

    func initialize(_ server: HBHTTPServer, channel: Channel, responder: HBHTTPResponder) -> EventLoopFuture<Void> {
        channel.configureHTTP2SecureUpgrade(
            h2ChannelConfigurator: { channel in
                channel.configureHTTP2Pipeline(
                    mode: .server,
                    inboundStreamInitializer: { channel in
                        channel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { () -> EventLoopFuture<Void> in
                            server.addChildHandlers(channel: channel, responder: responder)
                        }.map { _ in
                            
                        }
                    }
                ).map { _ in }
            },
            http1ChannelConfigurator: { channel in
                http1.initialize(server, channel: channel, responder: responder)
            }
        )
    }
}

extension HBHTTPServer {
    public func upgradeToHTTP2() -> HBHTTPServer {
        self.httpChannelInitializer = HTTP2ChannelInitializer()
        return self
    }
    
    public func addHTTP2Upgrade(tlsConfiguration: TLSConfiguration) throws -> HBHTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("h2")
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        
        self.httpChannelInitializer = HTTP2UpgradeChannelInitializer()
        return self.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
    }
}
