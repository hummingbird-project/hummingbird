import Logging
import NIO
import NIOHTTP1

/// Protocol for objects generating a `HBHTTPResponse` from a `HBHTTPRequest`
public protocol HBHTTPResponder {
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse>
    var logger: Logger? { get }
}

/// Channel handler for responding to a request and returning a response
public final class HBHTTPServerHandler: ChannelInboundHandler {
    public typealias InboundIn = HBHTTPRequest
    public typealias OutboundOut = HBHTTPResponse

    let responder: HBHTTPResponder
    
    var responsesInProgress: Int
    var closeAfterResponseWritten: Bool
    var propagatedError: Error?

    public init(responder: HBHTTPResponder) {
        self.responder = responder
        self.responsesInProgress = 0
        self.closeAfterResponseWritten = false
        self.propagatedError = nil
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = unwrapInboundIn(data)
        // if error caught from previous channel handler then write an error
        if let error = propagatedError {
            let keepAlive = request.head.isKeepAlive && self.closeAfterResponseWritten == false
            writeError(context: context, error: error, keepAlive: keepAlive)
            self.propagatedError = nil
            return
        }
        self.responsesInProgress += 1

        // respond to request
        self.responder.respond(to: request, context: context).whenComplete { result in
            // should we close the channel after responding
            let keepAlive = request.head.isKeepAlive && self.closeAfterResponseWritten == false
            switch result {
            case .failure(let error):
                self.writeError(context: context, error: error, keepAlive: keepAlive)

            case .success(var response):
                response.head.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
                self.writeResponse(context: context, response: response, keepAlive: keepAlive)
            }
        }
    }

    func writeResponse(context: ChannelHandlerContext, response: HBHTTPResponse, keepAlive: Bool) {
        context.write(self.wrapOutboundOut(response)).whenComplete { _ in
            if keepAlive == false {
                context.close(promise: nil)
                self.closeAfterResponseWritten = false
            }
            self.responsesInProgress -= 1
        }
    }

    func writeError(context: ChannelHandlerContext, error: Error, keepAlive: Bool) {
        var response: HBHTTPResponse
        switch error {
        case let httpError as HBHTTPError:
            response = httpError.response(allocator: context.channel.allocator)
        default:
            response = HBHTTPResponse(
                head: .init(version: .init(major: 1, minor: 1), status: .internalServerError),
                body: .empty
            )
        }
        response.head.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
        self.writeResponse(context: context, response: response, keepAlive: keepAlive)
    }

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            // The remote peer half-closed the channel. At this time, any
            // outstanding response will be written before the channel is
            // closed, and if we are idle or waiting for a request body to
            // finish wewill close the channel immediately.
            if self.responsesInProgress > 1 {
                self.closeAfterResponseWritten = true
            } else {
                context.close(promise: nil)
            }
        default:
            self.responder.logger?.debug("Unhandled event \(event as? ChannelEvent)")
            context.fireUserInboundEventTriggered(event)
        }
    }

    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.propagatedError = error
    }
}
