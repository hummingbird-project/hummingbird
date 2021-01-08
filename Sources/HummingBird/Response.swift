import NIO
import NIOHTTP1

public struct Response {
    public let status: HTTPResponseStatus
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
}

