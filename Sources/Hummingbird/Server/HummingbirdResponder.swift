import HummingbirdCore
import Logging
import NIO
import NIOHTTP1

struct HummingbirdResponder: HBHTTPResponder {
    let application: HBApplication
    let responder: HBResponder

    init(application: HBApplication) {
        self.application = application
        // application responder has been set for sure
        self.responder = application.responder!
    }
    
    var logger: Logger? { return self.application.logger }
    
    func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
        let request = HBRequest(
            head: request.head,
            body: request.body,
            application: application,
            context: context
        )

        // respond to request
        return self.responder.respond(to: request).map { response in
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: response.status, headers: response.headers)
            return HBHTTPResponse(head: responseHead, body: response.body)
        }
    }
}

