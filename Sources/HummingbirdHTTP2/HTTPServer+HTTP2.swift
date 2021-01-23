import HummingbirdCore
import NIO
import NIOHTTP2
import NIOSSL

extension HBHTTPServer {
    /// Add HTTP2 secure upgrade handler
    ///
    /// HTTP2 secure upgrade requires a TLS connection so this will add a TLS handler as well. Do not call `addTLS()` inconjunction with this as
    /// you will then be adding two TLS handlers.
    ///
    /// - Parameter tlsConfiguration: TLS configuration
    @discardableResult public func addHTTP2Upgrade(tlsConfiguration: TLSConfiguration) throws -> HBHTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("h2")
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        
        self.httpChannelInitializer = HTTP2UpgradeChannelInitializer()
        return self.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
    }

    /// Set HTTP server to use HTTP2. This assumes that HTTP2 will have already been negotiated. In general you are more likely to use
    ///`addHTTP2Upgrade` so the HTTP version can be negotiated.
    @discardableResult public func setHTTP2() -> HBHTTPServer {
        self.httpChannelInitializer = HTTP2ChannelInitializer()
        return self
    }
}
