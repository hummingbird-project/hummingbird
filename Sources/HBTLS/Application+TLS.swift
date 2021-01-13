import HummingBird
import NIO
import NIOSSL

extension Application {
    /// Add HTTPS server to application
    /// - Parameters:
    ///   - configuration: General HTTP configuration
    ///   - tlsConfiguration: TLS configuration
    @discardableResult public func addHTTPS(_ configuration: HTTPServer.Configuration, tlsConfiguration: TLSConfiguration) throws -> HTTPServer {
        var tlsConfiguration = tlsConfiguration
        tlsConfiguration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        
        let server = HTTPServer(group: self.eventLoopGroup, configuration: configuration)
        server.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .first)
        addServer(server, named: "HTTPS")
        
        return server
    }
    
    public var https: HTTPServer? { servers["HTTPS"] as? HTTPServer }
}
