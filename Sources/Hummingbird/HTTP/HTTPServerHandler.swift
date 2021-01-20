import Logging
import NIO
import NIOHTTP1

/// Channel handler for responding to a request and returning a response
final class HTTPServerHandler: ChannelInboundHandler {
    typealias InboundIn = Request
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
        let request = unwrapInboundIn(data)

        // if error caught from previous channel handler then write an error
        if let error = propagatedError {
            let keepAlive = request.isKeepAlive && self.closeAfterResponseWritten == false
            writeError(context: context, error: error, keepAlive: keepAlive)
            self.propagatedError = nil
            return
        }
        self.responsesInProgress += 1

        // respond to request
        self.responder.respond(to: request).whenComplete { result in
            // should we close the channel after responding
            let keepAlive = request.isKeepAlive && self.closeAfterResponseWritten == false
            switch result {
            case .failure(let error):
                self.writeError(context: context, error: error, keepAlive: keepAlive)

            case .success(let response):
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
