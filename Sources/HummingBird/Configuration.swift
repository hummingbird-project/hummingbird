
extension Application {
    public enum Address {
        case hostname(_ hostname: String?, port: Int?)
        case unixDomainSocket(path: String)
    }

    public struct Configuration {
        /// bind address port
        public let port: Int
        /// bind address host
        public let host: String
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// pipelining ensures that only one http request is processed at one time
        public let enableHttpPipelining: Bool

        /// max upload size
        public let maxUploadSize: Int

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            enableHttpPipelining: Bool = false,
            maxUploadSize: Int = 2 * 1024 * 1024
        ) {
            self.host = host
            self.port = port
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.enableHttpPipelining = enableHttpPipelining
            self.maxUploadSize = maxUploadSize
        }

        var httpServer: HTTPServer.Configuration {
            return .init(
                host: self.host,
                port: self.port,
                reuseAddress: self.reuseAddress,
                tcpNoDelay: self.tcpNoDelay,
                withPipeliningAssistance: self.enableHttpPipelining
            )
        }
    }
}
