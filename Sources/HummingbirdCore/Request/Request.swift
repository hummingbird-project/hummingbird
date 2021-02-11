import NIO
import NIOHTTP1

/// HTTP request
public struct HBHTTPRequest {
    public var head: HTTPRequestHead
    public var body: HBRequestBody
}
