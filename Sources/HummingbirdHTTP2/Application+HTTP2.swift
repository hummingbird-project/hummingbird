import Hummingbird
import NIOSSL

extension HBApplication {
    /// Add HTTP2 secure upgrade handler
    ///
    /// HTTP2 secure upgrade requires a TLS connection so this will add a TLS handler as well. Do not call `addTLS()` inconjunction with this as
    /// you will then be adding two TLS handlers.
    ///
    /// - Parameter tlsConfiguration: TLS configuration
    public func addHTTP2Upgrade(tlsConfiguration: TLSConfiguration) throws {
        try self.server.addHTTP2Upgrade(tlsConfiguration: tlsConfiguration)
    }
}
