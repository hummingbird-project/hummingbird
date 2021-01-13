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
        self.middlewares.add(middleware)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: ResponseGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) throws -> R) {
        let responder = CallbackResponder(callback: { request in
            do {
                let response = try closure(request).response(from: request)
                return request.eventLoop.makeSucceededFuture(response)
            } catch {
                return request.eventLoop.makeFailedFuture(error)
            }
        })
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: ResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> R) {
        let responder = CallbackResponder(callback: { request in closure(request).responseFuture(from: request) })
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
    }
}
