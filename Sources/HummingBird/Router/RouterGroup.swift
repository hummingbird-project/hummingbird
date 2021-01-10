import NIO
import NIOHTTP1

public struct RouterGroup: RouterPaths {
    let router: Router
    let middlewares: MiddlewareGroup
    
    init(router: Router) {
        self.router = router
        self.middlewares = .init()
    }

    /// Add middleware to RouterGroup
    public func add(middleware: Middleware) -> RouterGroup {
        middlewares.add(middleware)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: ResponseFutureEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder(callback: { request in closure(request).responseFuture(from: request) })
        router.add(path, method: method, responder: middlewares.constructResponder(finalResponder: responder))
    }
    
    /// Add path for closure returning type conforming to Codable
    public func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder(callback: { request in
            do {
                let value = closure(request)
                var buffer = request.allocator.buffer(capacity: 0)
                try request.application.encoder.encode(value, to: &buffer)
                let response = Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
                return request.eventLoop.makeSucceededFuture(response)
            } catch {
                return request.eventLoop.makeFailedFuture(error)
            }
        })
        router.add(path, method: method, responder: middlewares.constructResponder(finalResponder: responder))
    }

    /// Add path for closure returning `EventLoopFuture` of type conforming to Codable
    public func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        let responder = CallbackResponder(callback: { request in
            closure(request).flatMapThrowing { response in
                var buffer = request.allocator.buffer(capacity: 0)
                try request.application.encoder.encode(response, to: &buffer)
                return Response(status: .ok, headers: [:], body: .byteBuffer(buffer))
            }
        })
        router.add(path, method: method, responder: middlewares.constructResponder(finalResponder: responder))
    }
}
