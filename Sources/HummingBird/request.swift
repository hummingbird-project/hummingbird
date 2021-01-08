import NIO
import NIOHTTP1

struct Request {
    let headers: HTTPHeaders
    let body: ByteBuffer?
    let eventLoop: EventLoop
    let allocator: ByteBufferAllocator
}
