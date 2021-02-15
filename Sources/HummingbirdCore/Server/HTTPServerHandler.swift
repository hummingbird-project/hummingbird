import Logging
import NIO
import NIOHTTP1

/// Channel handler for responding to a request and returning a response
final class HBHTTPServerHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = HBHTTPRequest
    typealias OutboundOut = HBHTTPResponse

    let responder: HBHTTPResponder

    var requestsInProgress: Int
    var closeAfterResponseWritten: Bool
    var propagatedError: Error?

    init(responder: HBHTTPResponder) {
        self.responder = responder
        self.requestsInProgress = 0
        self.closeAfterResponseWritten = false
        self.propagatedError = nil
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.responder.handlerAdded(context: context)
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.responder.handlerRemoved(context: context)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let request = unwrapInboundIn(data)
        // if error caught from previous channel handler then write an error
        if let error = propagatedError {
            let keepAlive = request.head.isKeepAlive && self.closeAfterResponseWritten == false
            var response = self.getErrorResponse(context: context, error: error, version: request.head.version)
            if request.head.version.major == 1 {
                response.head.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
            }
            self.writeResponse(context: context, response: response, request: request, keepAlive: keepAlive)
            self.propagatedError = nil
            return
        }
        self.requestsInProgress += 1

        // respond to request
        self.responder.respond(to: request, context: context).whenComplete { result in
            // should we close the channel after responding
            let keepAlive = request.head.isKeepAlive && self.closeAfterResponseWritten == false
            var response: HBHTTPResponse
            switch result {
            case .failure(let error):
                response = self.getErrorResponse(context: context, error: error, version: request.head.version)

            case .success(let successfulResponse):
                response = successfulResponse
            }
            if request.head.version.major == 1 {
                response.head.headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")
            }
            self.writeResponse(context: context, response: response, request: request, keepAlive: keepAlive)
        }
    }

    func writeResponse(context: ChannelHandlerContext, response: HBHTTPResponse, request: HBHTTPRequest, keepAlive: Bool) {
        context.write(self.wrapOutboundOut(response)).whenComplete { _ in
            if keepAlive == false {
                context.close(promise: nil)
                self.closeAfterResponseWritten = false
            }
            self.requestsInProgress -= 1
            // once we have finished writing the response we can drop the request body
            if case .stream(let streamer) = request.body {
                streamer.drop()
            }
        }
    }

    func getErrorResponse(context: ChannelHandlerContext, error: Error, version: HTTPVersion) -> HBHTTPResponse {
        self.responder.logger?.error("\(error)")
        switch error {
        case let httpError as HBHTTPResponseError:
            return httpError.response(version: version, allocator: context.channel.allocator)
        default:
            return HBHTTPResponse(
                head: .init(version: version, status: .internalServerError),
                body: .empty
            )
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            // The remote peer half-closed the channel. At this time, any
            // outstanding response will be written before the channel is
            // closed, and if we are idle we will close the channel immediately.
            if self.requestsInProgress > 0 {
                self.closeAfterResponseWritten = true
            } else {
                context.close(promise: nil)
            }

        case is ChannelShouldQuiesceEvent:
            // we received a quiesce event. If we have any requests in progress we should
            // wait for them to finish
            if self.requestsInProgress > 0 {
                self.closeAfterResponseWritten = true
            } else {
                context.close(promise: nil)
            }

        default:
            self.responder.logger?.debug("Unhandled event \(event as? ChannelEvent)")
            context.fireUserInboundEventTriggered(event)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.propagatedError = error
    }
}
