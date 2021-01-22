import NIO

/// Applied to request before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// by calling `next.apply(to: request)`. If you want to shortcut the request you can return a response immediately
public protocol HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse>
}

struct MiddlewareResponder: HBResponder {
    let middleware: HBMiddleware
    let next: HBResponder

    func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        return self.middleware.apply(to: request, next: self.next)
    }
}
