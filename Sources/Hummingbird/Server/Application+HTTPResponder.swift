import HummingbirdCore
import Logging
import NIO
import NIOHTTP1

extension HBApplication {
    public struct HTTPResponder: HBHTTPResponder {
        let application: HBApplication
        let responder: HBResponder
        let handlerAddedCallback: (ChannelHandlerContext) -> Void
        let handlerRemovedCallback: (ChannelHandlerContext) -> Void

        public init(application: HBApplication) {
            self.application = application
            // application responder has been set for sure
            self.responder = application.constructResponder()
            self.handlerAddedCallback = { context in application.handlerAddedCallbacks.forEach { $0(context) } }
            self.handlerRemovedCallback = { context in application.handlerRemovedCallbacks.forEach { $0(context) } }
        }

        public var logger: Logger? { return self.application.logger }

        public func handlerAdded(context: ChannelHandlerContext) {
            self.handlerAddedCallback(context)
        }

        public func handlerRemoved(context: ChannelHandlerContext) {
            self.handlerRemovedCallback(context)
        }

        public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
            let request = HBRequest(
                head: request.head,
                body: request.body,
                application: self.application,
                context: context
            )

            // respond to request
            return self.responder.respond(to: request).map { response in
                let responseHead = HTTPResponseHead(version: request.version, status: response.status, headers: response.headers)
                return HBHTTPResponse(head: responseHead, body: response.body)
            }
        }
    }
}
