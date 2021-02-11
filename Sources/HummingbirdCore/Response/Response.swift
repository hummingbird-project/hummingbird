import NIO
import NIOHTTP1

/// HTTP response
public struct HBHTTPResponse {
    public var head: HTTPResponseHead
    public var body: HBResponseBody

    public init(head: HTTPResponseHead, body: HBResponseBody) {
        self.head = head
        self.body = body
    }
}
