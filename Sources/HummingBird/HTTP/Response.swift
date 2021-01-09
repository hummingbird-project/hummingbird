import NIO
import NIOHTTP1

public struct Response {
    public let status: HTTPResponseStatus
    public let headers: HTTPHeaders
    public let body: ResponseBody

    public init(status: HTTPResponseStatus, headers: HTTPHeaders, body: ResponseBody) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

