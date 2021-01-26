import Hummingbird
import NIOSSL

extension HBApplication {
    /// Add Transport Layer Security to server
    /// - Parameter tlsConfiguration: TLS configuration
    public func addTLS(tlsConfiguration: TLSConfiguration) throws {
        try self.server.addTLS(tlsConfiguration: tlsConfiguration)
    }
}
