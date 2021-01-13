import HummingBird
import NIO
import NIOSSL

extension Application {
    public func installTLS(configuration: TLSConfiguration) throws {
        var configuration = configuration
        configuration.applicationProtocols.append("http/1.1")
        let sslContext = try NIOSSLContext(configuration: configuration)
        self.server.addChildChannelHandler(NIOSSLServerHandler(context: sslContext), position: .first)
    }
}
