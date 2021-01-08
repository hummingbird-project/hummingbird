import NIO
import NIOHTTP1

public struct Response {
    public let status: HTTPResponseStatus
    public let headers: HTTPHeaders
    public let body: ByteBuffer?

    public init(status: HTTPResponseStatus, headers: HTTPHeaders, body: ByteBuffer?) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

