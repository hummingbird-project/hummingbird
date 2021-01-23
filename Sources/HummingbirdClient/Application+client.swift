import Hummingbird
import AsyncHTTPClient

extension HBApplication {
    /// Create HTTP Client
    public func createHTTPClient(configuration: HTTPClient.Configuration = .init()) {
        httpClient = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup), configuration: configuration)
    }

    /// Access HTTP client attached to HBApplication
    public var httpClient: HTTPClient {
        get { extensions.get(\.httpClient) }
        set { extensions.set(\.httpClient, value: newValue) { client in
            try? client.syncShutdown()
        } }
    }
}

