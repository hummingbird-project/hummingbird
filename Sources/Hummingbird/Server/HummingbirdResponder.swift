import HummingbirdCore
import Logging
import NIO
import NIOHTTP1

struct HummingbirdResponder: HTTPResponder {
    let application: Application
    let responder: RequestResponder

    init(application: Application) {
        self.application = application
        // application responder has been set for sure
        self.responder = application.responder!
    }
    
    var logger: Logger? { return self.application.logger }
    
    func respond(to request: HTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HTTPResponse> {
        let request = Request(
            head: request.head,
            body: request.body,
            application: application,
            context: context
        )

        // respond to request
        return self.responder.respond(to: request).map { response in
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: response.status, headers: response.headers)
            return HTTPResponse(head: responseHead, body: response.body)
        }
    }
}

