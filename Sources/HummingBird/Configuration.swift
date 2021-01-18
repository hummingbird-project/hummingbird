
extension Application {
    public enum Address {
        case hostname(_ hostname: String?, port: Int?)
        case unixDomainSocket(path: String)
    }

    public struct Configuration {
        public let port: Int
        public let host: String
        public let reuseAddress: Bool
        public let tcpNoDelay: Bool
        public let withPipeliningAssistance: Bool

        public init(
            host: String = "127.0.0.1",
            port: Int = 8080,
            reuseAddress: Bool = true,
            tcpNoDelay: Bool = false,
            withPipeliningAssistance: Bool = false
        ) {
            self.host = host
            self.port = port
            self.reuseAddress = reuseAddress
            self.tcpNoDelay = tcpNoDelay
            self.withPipeliningAssistance = withPipeliningAssistance
        }

        var httpServer: HTTPServer.Configuration {
            return .init(
                host: self.host,
                port: self.port,
                reuseAddress: self.reuseAddress,
                tcpNoDelay: self.tcpNoDelay,
                withPipeliningAssistance: self.withPipeliningAssistance
            )
        }
    }
}
