import NIO

/// Applied to request before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// by calling `next.apply(to: request)`. 
public protocol Middleware {
    func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response>
}

struct MiddlewareResponder: RequestResponder {
    let middleware: Middleware
    let next: RequestResponder

    func respond(to request: Request) -> EventLoopFuture<Response> {
        return middleware.apply(to:request, next: next)
    }
}
