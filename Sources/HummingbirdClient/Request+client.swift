import AsyncHTTPClient
import Hummingbird

extension HBRequest {
    var httpClient: HTTPClient { return application.httpClient }
}
