import NIO

/// Object that produces a response given a request
public protocol RequestResponder {
    func apply(to request: Request) -> EventLoopFuture<Response>
}

/// Responder that calls supplied closure 
struct CallbackResponder: RequestResponder {
    let callback: (Request) -> EventLoopFuture<Response>
    func apply(to request: Request) -> EventLoopFuture<Response> {
        return callback(request)
    }
}

