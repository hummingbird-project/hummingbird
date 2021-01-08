import NIO
import NIOHTTP1

public protocol Router: Responder {
    func add(_ path: String, method: HTTPMethod, responder: Responder)
}

extension Router {
    public func add<R: ResponseEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        let responder = CallbackResponder(callback: { request in closure(request).map { $0.response } })
        add(path, method: method, responder: responder)
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
    
    public func add<R: Encodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        let responder = CallbackResponder(callback: { request in
            closure(request).flatMapThrowing { response in
                var buffer = request.allocator.buffer(capacity: 0)
                try request.application.encoder.encode(response, to: &buffer)
                return Response(status: .ok, headers: [:], body: buffer)
            }
        })
        add(path, method: method, responder: responder)
    }
    
    public func get<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .GET, closure: closure)
    }
    
    public func put<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .PUT, closure: closure)
    }
    
    public func post<R: Encodable>(_ path: String, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(path, method: .POST, closure: closure)
    }
    
    public func group() -> RouterGroup {
        return .init(router: self)
    }
}
