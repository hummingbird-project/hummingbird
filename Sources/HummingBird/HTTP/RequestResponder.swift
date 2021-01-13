import NIO

/// Object that produces a response given a request
public protocol RequestResponder {
    func respond(to request: Request) -> EventLoopFuture<Response>
}

/// Responder that calls supplied closure
struct CallbackResponder: RequestResponder {
    let callback: (Request) -> EventLoopFuture<Response>
    func respond(to request: Request) -> EventLoopFuture<Response> {
        return self.callback(request)
    }
}
