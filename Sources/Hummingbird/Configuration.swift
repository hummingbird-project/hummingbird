import HummingbirdCore

extension HBApplication {
    /// Application configuration
    public struct Configuration {
        /// bind address
        public let address: HBBindAddress
        /// Allows socket to be bound to an address that is already in use.
        public let reuseAddress: Bool
        /// Disables the Nagle algorithm for send coalescing.
        public let tcpNoDelay: Bool
        /// pipelining ensures that only one http request is processed at one time
        public let enableHttpPipelining: Bool

        /// max upload size
        public let maxUploadSize: Int

        public init(
            address: HBBindAddress = .hostname(),
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

        var httpServer: HBHTTPServer.Configuration {
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
