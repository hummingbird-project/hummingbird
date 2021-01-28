import HummingbirdCore
import NIOSSL

extension HBHTTPServer {
    @discardableResult public func addTLS(tlsConfiguration: TLSConfiguration) throws -> HBHTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)

        return self.addChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
    }
}
