import NIO
import NIOHTTP1

/// Responder that chooses the next responder to call based on the request method
class HBEndpointResponder: HBResponder {
    init(path: String) {
        self.path = path
        self.methods = [:]
    }

    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        guard let responder = methods[request.method.rawValue] else {
            return request.failure(HBHTTPError(.notFound))
        }
        return responder.respond(to: request)
    }

    func addResponder(for method: HTTPMethod, responder: HBResponder) {
        guard self.methods[method.rawValue] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        self.methods[method.rawValue] = responder
    }

    var methods: [String: HBResponder]
    var path: String
}
