import NIO
import NIOHTTP1

public class BasicRouter: Router {
    var routes: [Substring: [String: Responder]]
    
    init() {
        routes = [:]
    }
    
    public func add(_ path: String, method: HTTPMethod, responder: Responder) {
        let substring = path[...]
        if routes[substring] != nil {
            routes[substring]?[method.rawValue] = responder
        } else {
            routes[substring] = [method.rawValue: responder]
        }
    }
    
    public func apply(to request: Request) -> EventLoopFuture<Response> {
        if let routesForPath = routes[request.path.path] {
            if let route = routesForPath[request.method.rawValue] {
                return route.apply(to: request)
            }
        }
        return request.eventLoop.makeFailedFuture(HTTPError(error: .notFound))
    }
}
