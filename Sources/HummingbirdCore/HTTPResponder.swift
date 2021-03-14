import Logging
import NIO

/// Protocol for objects generating a `HBHTTPResponse` from a `HBHTTPRequest`.
///
/// This is the core interface to the HummingbirdCore library. You need to provide an object that conforms
/// to `HBHTTPResponder` when you call `HTTPServer.start`. This object is used to define how
/// you convert requests to the server into responses
///
/// This is an example `HBHTTPResponder` that replies with a response with body "Hello"
/// ```
/// struct HelloResponder: HBHTTPResponder {
///     func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
///         let response = HBHTTPResponse(
///             head: .init(version: .init(major: 1, minor: 1), status: .ok),
///             body: .byteBuffer(context.channel.allocator.buffer(string: "Hello"))
///         )
///         return context.eventLoop.makeSucceededFuture(response)
///    }
/// }
/// ```
/// The following will start up a server using the above `HelloResponder`.
/// ```
/// let server = HBHTTPServer(
///     group: eventLoopGroup,
///     configuration: .init(address: .hostname("127.0.0.1", port: 8080))
/// )
/// try server.start(responder: HelloResponder()).wait()
/// ```
public protocol HBHTTPResponder {
    /// Called when HTTP server handler is added to channel
    func handlerAdded(context: ChannelHandlerContext)

    /// Called when HTTP server handler is removed from channel
    func handlerRemoved(context: ChannelHandlerContext)

    /// Returns an EventLoopFuture that will be fullfilled with the response to the request passed in to the function
    /// - Parameters:
    ///   - request: HTTP request
    ///   - context: ChannelHandlerContext from channel that request was served on.
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void)

    /// Logger used by responder
    var logger: Logger? { get }
}

extension HBHTTPResponder {
    public func handlerAdded(context: ChannelHandlerContext) {}
    public func handlerRemoved(context: ChannelHandlerContext) {}
    public var logger: Logger? { nil }
}
