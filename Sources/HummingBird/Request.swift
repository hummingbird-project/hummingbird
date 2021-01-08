import NIO
import NIOHTTP1

public struct Request {
    public let path: String
    public let method: HTTPMethod
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
    public let eventLoop: EventLoop
    public let allocator: ByteBufferAllocator
}
