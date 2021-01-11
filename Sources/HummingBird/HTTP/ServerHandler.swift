import Logging
import NIO

final class ServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPInHandler.Request
    typealias OutboundOut = Response
    
    let responder: RequestResponder
    let application: Application

    init(application: Application) {
        self.application = application
        // application responder has been set for sure
        self.responder = application.responder!
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let rawRequest = unwrapInboundIn(data)
        let request = Request(
            uri: URI(rawRequest.head.uri),
            method: rawRequest.head.method,
            headers: rawRequest.head.headers,
            body: rawRequest.body,
            application: application,
            eventLoop: context.eventLoop,
            allocator: context.channel.allocator
        )
        responder.respond(to: request).whenComplete { result in
            switch result {
            case .failure(let error):
                let status: HTTPResponseStatus
                switch error {
                case let httpError as HTTPError:
                    status = httpError.status
                default:
                    status = .internalServerError
                }
                let response = Response(status: status, headers: [:], body: .empty)
                self.writeResponse(context: context, response: response, keepAlive: rawRequest.head.isKeepAlive)
            case .success(let response):
                self.writeResponse(context: context, response: response, keepAlive: rawRequest.head.isKeepAlive)
            }
        }
    }
    
    func writeResponse(context: ChannelHandlerContext, response: Response, keepAlive: Bool) {
        context.writeAndFlush(self.wrapOutboundOut(response)).whenComplete { _ in
            if keepAlive == false {
                context.close(promise: nil)
            }
        }
    }
}
