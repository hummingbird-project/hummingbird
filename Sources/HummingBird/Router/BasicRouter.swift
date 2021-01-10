import NIO
import NIOHTTP1

public class BasicRouter: Router {
    var routes: [Substring: [String: RequestResponder]]
    
    init() {
        routes = [:]
    }
    
    public func add(_ path: String, method: HTTPMethod, responder: RequestResponder) {
        let substring = path[...]
        if routes[substring] != nil {
            routes[substring]?[method.rawValue] = responder
        } else {
            routes[substring] = [method.rawValue: responder]
        }
    }
    
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        if let routesForPath = routes[request.uri.path] {
            if let route = routesForPath[request.method.rawValue] {
                return route.respond(to: request)
            }
        }
        return request.eventLoop.makeFailedFuture(HTTPError(.notFound))
    }
}
