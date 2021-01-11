import Logging
import NIO
import NIOHTTP1

public struct Request {
    public let uri: URI
    public let method: HTTPMethod
    public let headers: HTTPHeaders
    public let body: ByteBuffer?
    public let logger: Logger
    public let application: Application
    public let eventLoop: EventLoop
    public let allocator: ByteBufferAllocator

    public func decode<Type: Codable>(as type: Type.Type) throws -> Type {
        guard var buffer = self.body else {
            throw HTTPError(.badRequest)
        }
        return try application.decoder.decode(type, from: &buffer)
    }
}
