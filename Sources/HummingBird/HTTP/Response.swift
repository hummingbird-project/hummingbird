import NIO
import NIOHTTP1

/// HTTP Response
public struct Response {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: ResponseBody

    public init(status: HTTPResponseStatus, headers: HTTPHeaders, body: ResponseBody) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}
