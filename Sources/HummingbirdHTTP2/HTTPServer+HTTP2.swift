import HummingbirdCore
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
        return self.addChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
    }
}
