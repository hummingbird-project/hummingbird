import NIO
import NIOHTTP1

public struct Request {
    public let path: URI
    public let method: HTTPMethod
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
    public let application: Application
    public let eventLoop: EventLoop
    public let allocator: ByteBufferAllocator
}
