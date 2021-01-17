import HummingBird
import NIOSSL

extension HTTPServer {
    @discardableResult public func addTLS(tlsConfiguration: TLSConfiguration) throws -> HTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        
        self.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .beforeHTTP)
        return self
    }
}

