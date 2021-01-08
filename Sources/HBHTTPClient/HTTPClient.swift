import NIO
import NIOHTTP1
import NIOSSL

public final class HTTPClient {
    public struct Request {
        public let url: String
        public let method: HTTPMethod
        public let headers: HTTPHeaders
        public let body: ByteBuffer?
    }

    public struct Response {
        public let headers: HTTPHeaders
        public let status: HTTPResponseStatus
        public let body: ByteBuffer?
    }

    public struct Configuration {
        public let tlsConfiguration: TLSConfiguration?

        public init(
            tlsConfiguration: TLSConfiguration? = nil
        ) {
            self.tlsConfiguration = tlsConfiguration
        }
    }

    public let eventLoopGroupProvider: NIOEventLoopGroupProvider
    public let eventLoopGroup: EventLoopGroup
    public let configuration: Configuration

    public init(_ eventLoopGroupProvider: NIOEventLoopGroupProvider, configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch eventLoopGroupProvider {
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        case .shared(let elg):
            self.eventLoopGroup = elg
        }
    }

    public func syncShutdown() throws {
        switch self.eventLoopGroupProvider {
        case .createNew:
            try eventLoopGroup.syncShutdownGracefully()
        default:
            break
        }
    }

    /*public func execute(_ request: Request) -> EventLoopFuture<Response> {

    }*/

/*    func getBootstrap(_ request: Request) throws -> NIOClientTCPBootstrap {
        let tlsConfiguration = configuration.tlsConfiguration ?? TLSConfiguration.forClient()
        let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        let hostname = (!requiresTLS || host.isIPAddress || host.isEmpty) ? nil : host
        let tlsProvider = try NIOSSLClientTLSProvider<ClientBootstrap>(context: sslContext, serverHostname: hostname)
        return NIOClientTCPBootstrap(self, tls: tlsProvider)
    }*/
}
