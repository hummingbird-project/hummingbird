import HummingbirdCore
import NIO
import NIOHTTP1

/// Apply additional middleware to a group of routes
public struct HBRouterGroup: HBRouterMethods {
    let router: HBRouter
    let middlewares: HBMiddlewareGroup

    init(router: HBRouter) {
        self.router = router
        self.middlewares = .init()
    }

    /// Add middleware to RouterGroup
    public func add(middleware: HBMiddleware) -> HBRouterGroup {
        self.middlewares.add(middleware)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (HBRequest) throws -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (HBRequest) -> R) {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request)
            }
        }
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func addStreamingRoute<R: HBResponseFutureGenerator>(_ path: String, method: HTTPMethod, closure: @escaping (HBRequest) -> R) {
        let responder = CallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request)
        }
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
    }

}
