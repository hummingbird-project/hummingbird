import NIO
import NIOHTTP1

public struct RouterGroup {
    let router: Router
    let middlewares: MiddlewareGroup
    
    init(router: Router) {
        self.router = router
        self.middlewares = .init()
    }
    
    public func add(middleware: Middleware) -> RouterGroup {
        middlewares.add(middleware)
        return self
    }

    public func add<R: ResponseEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        let responder = CallbackResponder(callback: { request in closure(request).map { $0.response } })
        router.add(
            path,
            method: method,
            responder: middlewares.constructResponder(finalResponder: responder)
        )
    }
    
    public func get<R: ResponseEncodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .GET, closure: closure)
    }
    
    public func put<R: ResponseEncodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .PUT, closure: closure)
    }
    
    public func post<R: ResponseEncodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .POST, closure: closure)
    }
}
