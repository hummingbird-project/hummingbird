import HummingbirdCore

extension HBApplication {
    /// Application configuration
    public struct Configuration {
        /// bind address
        public let address: HBBindAddress
        /// server name to return in "server" header
        public let serverName: String?
        /// max upload size
        public let maxUploadSize: Int
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// pipelining ensures that only one http request is processed at one time
        public let enableHttpPipelining: Bool

        /// number of threads to allocate in the application thread pool
        public let threadPoolSize: Int
        
        /// Create configuration struct
        public init(
            address: HBBindAddress = .hostname(),
            serverName: String? = nil,
            maxUploadSize: Int = 2 * 1024 * 1024,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            enableHttpPipelining: Bool = false,
            threadPoolSize: Int = 2
        ) {
            self.address = address
            self.serverName = serverName
            self.maxUploadSize = maxUploadSize
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.enableHttpPipelining = enableHttpPipelining

            self.threadPoolSize = threadPoolSize
        }
        
        /// return HTTP server configuration
        public var httpServer: HBHTTPServer.Configuration {
            return .init(
                address: self.address,
                serverName: self.serverName,
                maxUploadSize: self.maxUploadSize,
                reuseAddress: self.reuseAddress,
                tcpNoDelay: self.tcpNoDelay,
                withPipeliningAssistance: self.enableHttpPipelining
            )
        }
    }
}
