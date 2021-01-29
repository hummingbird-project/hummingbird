import Logging
import NIO

/// Protocol for objects generating a `HBHTTPResponse` from a `HBHTTPRequest`.
///
/// This is the core interface to the HummingbirdCore library. You need to provide an object that conforms
/// to `HBHTTPResponder` when you call `HTTPServer.start`. This object is used to define how
/// you convert requests to the server into responses
///
public protocol HBHTTPResponder {
    /// Called when HTTP server handler is added to channel
    func handlerAdded(context: ChannelHandlerContext)

    /// Called when HTTP server handler is removed from channel
    func handlerRemoved(context: ChannelHandlerContext)

    /// Returns an EventLoopFuture that will be fullfilled with the response to the request passed in to the function
    /// - Parameters:
    ///   - request: HTTP request
    ///   - context: ChannelHandlerContext from channel that request was served on.
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse>

    /// Logger used by responder
    var logger: Logger? { get }
}

extension HBHTTPResponder {
    public func handlerAdded(context: ChannelHandlerContext) {}
    public func handlerRemoved(context: ChannelHandlerContext) {}
    public var logger: Logger? { nil }
}
