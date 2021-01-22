
extension Application {
    /// Address to bind
    public enum Address {
        case hostname(_ host: String = "127.0.0.1", port: Int = 8080)
        case unixDomainSocket(path: String)

        /// if address is hostname and port return port
        public var port: Int? {
            guard case .hostname(_, let port) = self else { return nil }
            return port
        }

        /// if address is hostname and port return hostname
        public var host: String? {
            guard case .hostname(let host, _) = self else { return nil }
            return host
        }

        /// if address is unix domain socket return unix domain socket path
        public var unixDomainSocketPath: String? {
            guard case .unixDomainSocket(let path) = self else { return nil }
            return path
        }
    }

    /// Application configuration
    public struct Configuration {
        /// bind address
        public let address: Address
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// pipelining ensures that only one http request is processed at one time
        public let enableHttpPipelining: Bool

        /// max upload size
        public let maxUploadSize: Int

        public init(
            address: Address = .hostname(),
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            enableHttpPipelining: Bool = false,
            maxUploadSize: Int = 2 * 1024 * 1024
        ) {
            self.address = address
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.enableHttpPipelining = enableHttpPipelining
            self.maxUploadSize = maxUploadSize
        }

        var httpServer: HTTPServer.Configuration {
            return .init(
                address: self.address,
                reuseAddress: self.reuseAddress,
                tcpNoDelay: self.tcpNoDelay,
                withPipeliningAssistance: self.enableHttpPipelining,
                maxUploadSize: self.maxUploadSize
            )
        }
    }
}
