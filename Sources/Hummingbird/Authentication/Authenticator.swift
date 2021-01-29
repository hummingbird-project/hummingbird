import NIO

public protocol HBAuthenticator: HBMiddleware {
    func authenticate(request: HBRequest) -> EventLoopFuture<Void>
}

extension HBAuthenticator {
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        authenticate(request: request).flatMap {
            next.respond(to: request)
        }
    }
}
