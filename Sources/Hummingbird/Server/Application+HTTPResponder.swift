import HummingbirdCore
import Logging
import NIO
import NIOHTTP1

extension HBApplication {
    /// HTTP responder class for Hummingbird. This is the interface between Hummingbird and HummingbirdCore
    ///
    /// The HummingbirdCore server calls `respond` to get the HTTP response from Hummingbird
    public struct HTTPResponder: HBHTTPResponder {
        let application: HBApplication
        let responder: HBResponder

        /// Construct HTTP responder
        /// - Parameter application: application creating this responder
        public init(application: HBApplication) {
            self.application = application
            // application responder has been set for sure
            self.responder = application.constructResponder()
        }

        /// Logger used by responder
        public var logger: Logger? { return self.application.logger }

        /// Return EventLoopFuture that will be fulfilled with the HTTP response for the supplied HTTP request
        /// - Parameters:
        ///   - request: request
        ///   - context: context from ChannelHandler
        /// - Returns: response
        public func respond(to request: HBHTTPRequest, context: ChannelHandlerContext) -> EventLoopFuture<HBHTTPResponse> {
            let request = HBRequest(
                head: request.head,
                body: request.body,
                application: self.application,
                eventLoop: context.eventLoop,
                allocator: context.channel.allocator
            )

            // respond to request
            return self.responder.respond(to: request).map { response in
                let responseHead = HTTPResponseHead(version: request.version, status: response.status, headers: response.headers)
                return HBHTTPResponse(head: responseHead, body: response.body)
            }
        }
    }
}
