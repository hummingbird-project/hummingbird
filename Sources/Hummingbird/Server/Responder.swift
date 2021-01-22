import NIO

/// Object that produces a response given a request
public protocol HBResponder {
    func respond(to request: HBRequest) -> EventLoopFuture<HBResponse>
}

/// Responder that calls supplied closure
struct CallbackResponder: HBResponder {
    let callback: (HBRequest) -> EventLoopFuture<HBResponse>
    func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        return self.callback(request)
    }
}
