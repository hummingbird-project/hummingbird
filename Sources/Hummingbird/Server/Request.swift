import HummingbirdCore
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

public class HBRequest {
    /// URI path
    public var uri: HBURL
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

    internal init(
        head: HTTPRequestHead,
        body: HBRequestBody,
        application: HBApplication,
        context: ChannelHandlerContext
    ) {
        self.uri = .init(head.uri)
        self.method = head.method
        self.headers = head.headers
        self.body = body
        self.logger = Self.loggerWithRequestId(application.logger)
        self.application = application
        self.eventLoop = context.eventLoop
        self.allocator = context.channel.allocator
        self.extensions = HBExtensions()
    }

    public func decode<Type: Codable>(as type: Type.Type) throws -> Type {
        return try self.application.decoder.decode(type, from: self)
    }

    public var parameters: HBParameters {
        get { extensions.get(\.parameters) }
        set { extensions.set(\.parameters, value: newValue) }
    }
    
    private static func loggerWithRequestId(_ logger: Logger) -> Logger {
        var logger = logger
        logger[metadataKey: "id"] = .string(Self.globalRequestID.add(1).description)
        return logger
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}
