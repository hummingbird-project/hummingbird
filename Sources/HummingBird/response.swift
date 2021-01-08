import NIO
import NIOHTTP1

struct Response {
    let status: HTTPResponseStatus
    let headers: HTTPHeaders
    let body: ByteBuffer?
}

