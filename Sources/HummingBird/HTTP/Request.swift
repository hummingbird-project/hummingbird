import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

public struct Request {
    /// URI path
    public var uri: URI
    /// Request HTTP method
    public var method: HTTPMethod
    /// Request HTTP headers
    public var headers: HTTPHeaders
    /// Body of HTTP request
    public var body: ByteBuffer?
    /// Logger to use
    public var logger: Logger
    /// reference to application
    public var application: Application
    /// EventLoop request is running on
    public var eventLoop: EventLoop
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator
    /// additional storage
    public var storage: Storage

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
        self.storage = Storage()
    }

    public func decode<Type: Codable>(as type: Type.Type) throws -> Type {
        return try self.application.decoder.decode(type, from: self)
    }

    private static func loggerWithRequestId(_ logger: Logger) -> Logger {
        var logger = logger
        logger[metadataKey: "id"] = .string(Self.globalRequestID.add(1).description)
        return logger
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}
