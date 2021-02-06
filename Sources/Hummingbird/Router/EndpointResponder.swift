import NIO
import NIOHTTP1

class HBEndpointResponder: HBResponder {
    init() {
        methods = [:]
    }
    
    func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        guard let responder = methods[request.method.rawValue] else {
            return request.failure(HBHTTPError(.notFound))
        }
        return responder.respond(to: request)
    }
    
    func addResponder(for method: HTTPMethod, responder: HBResponder) {
        guard methods[method.rawValue] == nil else {
            preconditionFailure("\(method.rawValue) already has a handler")
        }
        methods[method.rawValue] = responder
    }
    
    var methods: [String: HBResponder]
}
