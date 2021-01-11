import Logging
import NIO
import NIOConcurrencyHelpers
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

    internal init(
        uri: URI,
        method: HTTPMethod,
        headers: HTTPHeaders,
        body: ByteBuffer?,
        application: Application,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator
    ) {
        self.uri = uri
        self.method = method
        self.headers = headers
        self.body = body
        self.logger = Self.loggerWithRequestId(application.logger)
        self.application = application
        self.eventLoop = eventLoop
        self.allocator = allocator
    }

    public func decode<Type: Codable>(as type: Type.Type) throws -> Type {
        guard var buffer = self.body else {
            throw HTTPError(.badRequest)
        }
        return try application.decoder.decode(type, from: &buffer)
    }

    private static func loggerWithRequestId(_ logger: Logger) -> Logger {
        var logger = logger
        logger[metadataKey: "id"] = .string(Self.globalRequestID.add(1).description)
        return logger
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}
