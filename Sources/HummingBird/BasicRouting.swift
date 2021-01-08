import NIO
import NIOHTTP1

public protocol ResponseEncodable {
    var response: Response { get }
}

extension Response : ResponseEncodable {
    public var response: Response { self }
}

extension ByteBuffer: ResponseEncodable {
    public var response: Response {
        Response(status: .ok, headers: [:], body: self)
    }
}

public class BasicRouter: Responder {
    var routes: [String: [String: Responder]]
    
    init() {
        routes = [:]
    }
    
    func add(_ path: String, method: HTTPMethod, responder: Responder) {
        if routes[path] != nil {
            routes[path]?[method.rawValue] = responder
        } else {
            routes[path] = [method.rawValue: responder]
        }
    }
    
    public func add<R: ResponseEncodable>(_ path: String, method: HTTPMethod, closure: @escaping (Request) -> EventLoopFuture<R>) {
        add(
            path,
            method: method,
            responder: CallbackResponder(callback: { request in closure(request).map { $0.response } })
        )
    }
    
    func apply(to request: Request) -> EventLoopFuture<Response> {
        if let routesForPath = routes[request.path] {
            if let route = routesForPath[request.method.rawValue] {
                return route.apply(to: request)
            }
        }
        return request.eventLoop.makeFailedFuture(HTTPError(error: .notFound))
    }
}
