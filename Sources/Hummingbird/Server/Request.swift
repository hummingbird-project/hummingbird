import HummingbirdCore
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

public final class HBRequest: HBExtensible {
    /// URI path
    public var uri: HBURL
    /// HTTP version
    public var version: HTTPVersion
    /// Request HTTP method
    public var method: HTTPMethod
    /// Request HTTP headers
    public var headers: HTTPHeaders
    /// Body of HTTP request
    public var body: HBRequestBody
    /// Logger to use
    public var logger: Logger
    /// reference to application
    public var application: HBApplication
    /// EventLoop request is running on
    public var eventLoop: EventLoop
    /// ByteBuffer allocator used by request
    public var allocator: ByteBufferAllocator
    /// Request extensions
    public var extensions: HBExtensions<HBRequest>

    public init(
        head: HTTPRequestHead,
        body: HBRequestBody,
        application: HBApplication,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator
    ) {
        self.uri = .init(head.uri)
        self.version = head.version
        self.method = head.method
        self.headers = head.headers
        self.body = body
        self.logger = Self.loggerWithRequestId(application.logger)
        self.application = application
        self.eventLoop = eventLoop
        self.allocator = allocator
        self.extensions = HBExtensions()
    }

    public func decode<Type: Decodable>(as type: Type.Type) throws -> Type {
        return try self.application.decoder.decode(type, from: self)
    }

    public var parameters: HBParameters {
        get { self.extensions.get(\.parameters) }
        set { self.extensions.set(\.parameters, value: newValue) }
    }

    private static func loggerWithRequestId(_ logger: Logger) -> Logger {
        var logger = logger
        logger[metadataKey: "id"] = .string(Self.globalRequestID.add(1).description)
        return logger
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}

extension HBRequest {
    public func failure<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }

    public func success<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoop.makeSucceededFuture(value)
    }
}
