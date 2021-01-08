import NIO

protocol Middleware {
    func apply(to request: Request, next: Responder) -> EventLoopFuture<Response>
}

protocol Responder {
    func apply(to request: Request) -> EventLoopFuture<Response>
}

struct CallbackResponder: Responder {
    let callback: (Request) -> EventLoopFuture<Response>
    func apply(to request: Request) -> EventLoopFuture<Response> {
        return callback(request)
    }
}

struct MiddlewareResponder: Responder {
    let middleware: Middleware
    let next: Responder

    func apply(to request: Request) -> EventLoopFuture<Response> {
        return middleware.apply(to:request, next: next)
    }
}

public struct Middlewares {
    var middlewares: [Middleware]
    
    init() {
        middlewares = []
    }
    mutating func add(middleware: Middleware) {
        middlewares.append(middleware)
    }
}

struct MiddlewaresResponder: Responder {
    let middlewares: [Middleware]
    let rootResponder: Responder
    
    init(middlewares: Middlewares, finalResponder: Responder) {
        self.middlewares = middlewares.middlewares

        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: self.middlewares[i], next: currentResponser)
            currentResponser = responder
        }
        rootResponder = currentResponser
    }
    
    func apply(to request: Request) -> EventLoopFuture<Response> {
        return rootResponder.apply(to: request)
    }
}
