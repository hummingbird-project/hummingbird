import NIO
import NIOHTTP1

public class BasicRouter: Router {
    var routes: [Substring: [String: RequestResponder]]

    init() {
        self.routes = [:]
    }

    public func add(_ path: String, method: HTTPMethod, responder: RequestResponder) {
        let substring = path[...]
        if self.routes[substring] != nil {
            self.routes[substring]?[method.rawValue] = responder
        } else {
            self.routes[substring] = [method.rawValue: responder]
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
