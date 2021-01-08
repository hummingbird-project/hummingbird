import NIO

/// Applied to request before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// by calling `next.apply(to: request)`. 
public protocol Middleware {
    func apply(to request: Request, next: Responder) -> EventLoopFuture<Response>
}

struct MiddlewareResponder: Responder {
    let middleware: Middleware
    let next: Responder

    func apply(to request: Request) -> EventLoopFuture<Response> {
        return middleware.apply(to:request, next: next)
    }
}
