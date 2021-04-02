import HummingbirdCore
import Logging
import NIO
import NIOConcurrencyHelpers
import NIOHTTP1

/// Holds all the values required to process a request
public final class HBRequest: HBExtensible {
    // MARK: Member variables

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
    /// endpoint that services this request
    public var endpointPath: String?

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        get { self.extensions.getOrCreate(\.parameters, .init()) }
        set { self.extensions.set(\.parameters, value: newValue) }
    }

    // MARK: Initialization

    /// Create new HBRequest
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - application: reference to application that created this request
    ///   - eventLoop: EventLoop request processing is running on
    ///   - allocator: Allocator used by channel request processing is running on
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
        self.logger = application.logger.with(metadataKey: "hb_id", value: .string(Self.globalRequestID.add(1).description))
        self.application = application
        self.eventLoop = eventLoop
        self.allocator = allocator
        self.extensions = HBExtensions()
        self.endpointPath = nil
    }

    // MARK: Methods

    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type) throws -> Type {
        return try self.application.decoder.decode(type, from: self)
    }

    /// Return failed `EventLoopFuture`
    public func failure<T>(_ error: Error) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(error)
    }

    /// Return failed `EventLoopFuture` with http response status code
    public func failure<T>(_ status: HTTPResponseStatus) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status))
    }

    /// Return failed `EventLoopFuture` with http response status code and message
    public func failure<T>(_ status: HTTPResponseStatus, message: String) -> EventLoopFuture<T> {
        return self.eventLoop.makeFailedFuture(HBHTTPError(status, message: message))
    }

    /// Return succeeded `EventLoopFuture`
    public func success<T>(_ value: T) -> EventLoopFuture<T> {
        return self.eventLoop.makeSucceededFuture(value)
    }

    /// Return context request is running in
    public var context: Context {
        .init(logger: self.logger, eventLoop: self.eventLoop, allocator: self.allocator)
    }

    /// Context request is running in
    public struct Context {
        /// Logger to use
        public var logger: Logger
        /// EventLoop request is running on
        public var eventLoop: EventLoop
        /// ByteBuffer allocator used by request
        public var allocator: ByteBufferAllocator
    }

    private static let globalRequestID = NIOAtomic<Int>.makeAtomic(value: 0)
}

extension Logger {
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}
