import NIO
import NIOHTTP1

public protocol Router: Responder {
    func add(_ path: String, method: HTTPMethod, responder: Responder)
}

extension Router {
    public func add<R: ResponseEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(
            path,
            method: method,
            responder: CallbackResponder(callback: { request in closure(request).map { $0.response } })
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
    
    public func group() -> RouterGroup {
        return .init(router: self)
    }
}
