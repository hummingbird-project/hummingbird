import NIO
import NIOHTTP1

public class BasicRouter: Router {
    var routes: [String: [String: Responder]]
    
    init() {
        routes = [:]
    }
    
    public func add(_ path: String, method: HTTPMethod, responder: Responder) {
        if routes[path] != nil {
            routes[path]?[method.rawValue] = responder
        } else {
            routes[path] = [method.rawValue: responder]
        }
    }
    
    public func apply(to request: Request) -> EventLoopFuture<Response> {
        if let routesForPath = routes[request.path] {
            if let route = routesForPath[request.method.rawValue] {
                return route.apply(to: request)
            }
        }
        return request.eventLoop.makeFailedFuture(HTTPError(error: .notFound))
    }
}
