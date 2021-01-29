import HummingbirdCore
import NIO
import NIOHTTP1

/// Used to group together routes with additional middleware applied
///
/// The below create an `HBRouteEndpoint`with path "todos" and adds GET and PUT routes on "todos" and adds GET, PUT and
/// DELETE routes on "todos/:id" where id is the identifier for the todo
/// ```
/// let group = app.router
///     .group()
///     .add(middleware: MyMiddleware())
/// group
///     .get("path", use: myController.get)
///     .put("path", use: myController.put)
/// ```
public struct HBRouterGroup: HBRouterMethods {
    let router: HBRouter
    let middlewares: HBMiddlewareGroup

    init(router: HBRouter) {
        self.router = router
        self.middlewares = .init()
    }

    /// Add middleware to RouterEndpoint
    public func add(middleware: HBMiddleware) -> HBRouterGroup {
        self.middlewares.add(middleware)
        return self
    }

    public func endpoint(_ path: String) -> HBRouterEndpoint {
        return HBRouterEndpoint(path: path, middlewares: self.middlewares, router: self.router)
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) throws -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request)
            }
        }
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseFutureGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
            }
        }
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func onStreaming<R: HBResponseFutureGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = CallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request).hop(to: request.eventLoop)
        }
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}
