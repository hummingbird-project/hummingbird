import Logging
import NIO
import NIOHTTP1

final class HTTPServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPDecodeHandler.Request
    typealias OutboundOut = Response

    let responder: RequestResponder
    let application: Application

    var responsesInProgress: Int
    var closeAfterResponseWritten: Bool
    var propagatedError: Error?

    init(application: Application) {
        self.application = application
        // application responder has been set for sure
        self.responder = application.responder!
        self.responsesInProgress = 0
        self.closeAfterResponseWritten = false
        self.propagatedError = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let rawRequest = unwrapInboundIn(data)
        let request = Request(
            uri: URI(rawRequest.head.uri),
            method: rawRequest.head.method,
            headers: rawRequest.head.headers,
            body: rawRequest.body,
            application: self.application,
            eventLoop: context.eventLoop,
            allocator: context.channel.allocator
        )

        if let error = propagatedError {
            let keepAlive = rawRequest.head.isKeepAlive && self.closeAfterResponseWritten == false
            writeError(context: context, error: error, keepAlive: keepAlive)
            self.propagatedError = nil
            return
        }
        self.responsesInProgress += 1

        self.responder.respond(to: request).whenComplete { result in
            let keepAlive = rawRequest.head.isKeepAlive && self.closeAfterResponseWritten == false
            switch result {
            case .failure(let error):
                self.writeError(context: context, error: error, keepAlive: keepAlive)

            case .success(var response):
                response.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
                self.writeResponse(context: context, response: response, keepAlive: keepAlive)
            }
        }
    }

    func writeResponse(context: ChannelHandlerContext, response: Response, keepAlive: Bool) {
        context.write(self.wrapOutboundOut(response)).whenComplete { _ in
            if keepAlive == false {
                context.close(promise: nil)
                self.closeAfterResponseWritten = false
            }
            self.responsesInProgress -= 1
        }
    }

    func writeError(context: ChannelHandlerContext, error: Error, keepAlive: Bool) {
        var response: Response
        switch error {
        case let httpError as HTTPError:
            response = httpError.response(allocator: context.channel.allocator)
        default:
            response = Response(status: .internalServerError, headers: [:], body: .empty)
        }
        response.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
        self.writeResponse(context: context, response: response, keepAlive: keepAlive)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
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
            self.application.logger.debug("Unhandled event \(event as? ChannelEvent)")
            context.fireUserInboundEventTriggered(event)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.propagatedError = error
    }
}
