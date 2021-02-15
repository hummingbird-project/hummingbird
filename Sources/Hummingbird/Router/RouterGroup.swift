import HummingbirdCore
import NIO
import NIOHTTP1

/// Used to group together routes under a single path. Additional middleware can be added to the endpoint and each route can add a
/// suffix to the endpoint path
///
/// The code below creates an `HBRouterGroup`with path "todos" and adds GET and PUT routes on "todos" and adds GET, PUT and
/// DELETE routes on "todos/:id" where id is the identifier for the todo
/// ```
/// app.router
/// .group("todos")
/// .get(use: todoController.list)
/// .put(use: todoController.create)
/// .get(":id", use: todoController.get)
/// .put(":id", use: todoController.update)
/// .delete(":id", use: todoController.delete)
/// ```
public struct HBRouterGroup: HBRouterMethods {
    let path: String
    let router: HBRouter
    let middlewares: HBMiddlewareGroup

    init(path: String = "", middlewares: HBMiddlewareGroup = .init(), router: HBRouter) {
        self.path = path
        self.router = router
        self.middlewares = middlewares
    }

    /// Add middleware to RouterEndpoint
    public func add(middleware: HBMiddleware) -> HBRouterGroup {
        self.middlewares.add(middleware)
        return self
    }

    /// Return a group inside the current group
    /// - Parameter path: path prefix to add to routes inside this group
    public func group(_ path: String = "") -> HBRouterGroup {
        return HBRouterGroup(path: self.combinePaths(self.path, path), middlewares: self.middlewares, router: self.router)
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) throws -> R
    ) -> Self {
        let responder = HBCallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request).apply(patch: request.optionalResponse)
            }
        }
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseFutureGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = HBCallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMap { buffer in
                request.body = .byteBuffer(buffer)
                return closure(request).responseFuture(from: request)
                    .map { $0.apply(patch: request.optionalResponse) }
                    .hop(to: request.eventLoop)
            }
        }
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func onStreaming<R: HBResponseFutureGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        use closure: @escaping (HBRequest) -> R
    ) -> Self {
        let responder = HBCallbackResponder { request in
            let streamer = request.body.streamBody(on: request.eventLoop)
            request.body = .stream(streamer)
            return closure(request).responseFuture(from: request)
                .map { $0.apply(patch: request.optionalResponse) }
                .hop(to: request.eventLoop)
        }
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
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
