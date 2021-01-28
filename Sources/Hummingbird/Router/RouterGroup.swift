import HummingbirdCore
import NIO
import NIOHTTP1

/// Apply additional middleware to a group of routes
public struct HBRouterEndpoint: HBRouterMethods {
    let path: String
    let router: HBRouter
    let middlewares: HBMiddlewareGroup

    init(path: String, router: HBRouter) {
        self.path = path
        self.router = router
        self.middlewares = .init()
    }

    /// Add middleware to RouterGroup
    public func add(middleware: HBMiddleware) -> HBRouterEndpoint {
        self.middlewares.add(middleware)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseGenerator>(_ path: String = "", method: HTTPMethod, use closure: @escaping (HBRequest) throws -> R) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        let path = combinePaths(self.path, path)
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func add<R: HBResponseFutureGenerator>(_ path: String = "", method: HTTPMethod, use closure: @escaping (HBRequest) -> R) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
            }
        }
        let path = combinePaths(self.path, path)
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    public func addStreamingRoute<R: HBResponseFutureGenerator>(_ path: String = "", method: HTTPMethod, use closure: @escaping (HBRequest) -> R) -> Self {
        let responder = CallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
        }
        let path = combinePaths(self.path, path)
        router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    private func combinePaths(_ path1: String, _ path2: String) -> String {
        let path1 = path1.dropSuffix("/")
        let path2 = path2.dropPrefix("/")
        return "\(path1)/\(path2)"
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> Substring {
        if hasPrefix(prefix) {
            return self.dropFirst(prefix.count)
        } else {
            return self[...]
        }
    }

    func dropSuffix(_ suffix: String) -> Substring {
        if hasSuffix(suffix) {
            return self.dropLast(suffix.count)
        } else {
            return self[...]
        }
    }
}
