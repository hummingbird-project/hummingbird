import HummingbirdCore
import NIO
import NIOHTTP1

/// Directs Requests to handlers based on the request uri.
///
/// Conforms to `HBResponder` so need to provide its own implementation of
/// `func apply(to request: Request) -> EventLoopFuture<Response>`.
///
/// `HBRouter` requires an implementation of  the `on(path:method:use)` functions but because it
/// also conforms to `HBRouterMethods` it is also possible to call the method specific functions `get`, `put`,
/// `head`, `post` and `patch`.  The route handler closures all return objects conforming to
/// `HBResponseGenerator`.  This allows us to support routes which return a multitude of types eg
/// ```
/// app.router.get("string") { _ -> String in
///     return "string"
/// }
/// app.router.post("status") { _ -> HTTPResponseStatus in
///     return .ok
/// }
/// app.router.data("data") { request -> ByteBuffer in
///     return request.allocator.buffer(string: "buffer")
/// }
/// ```
/// Routes can also return `EventLoopFuture`'s. So you can support returning values from
/// asynchronous processes.
///
/// The default `Router` setup in `HBApplication` is the `TrieRouter` . This uses a
/// trie to partition all the routes for faster access. It also supports wildcards and parameter extraction
/// ```
/// app.router.get("user/*", use: anyUser)
/// app.router.get("user/:id", use: userWithId)
/// ```
/// Both of these match routes which start with "/user" and the next path segment being anything.
/// The second version extracts the path segment out and adds it to `HBRequest.parameters` with the
/// key "id".
public protocol HBRouter: HBRouterMethods, HBResponder {
    /// Add router entry
    func add(_ path: String, method: HTTPMethod, responder: HBResponder)
}

extension HBRouter {
    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        use closure: @escaping (HBRequest) throws -> R
    ) -> Self {
        let responder = HBCallbackResponder { request in
            request.body.consumeBody(on: request.eventLoop).flatMapThrowing { buffer in
                request.body = .byteBuffer(buffer)
                return try closure(request).response(from: request).apply(patch: request.optionalResponse)
            }
        }
        add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<R: HBResponseFutureGenerator>(
        _ path: String,
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
        add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func onStreaming<R: HBResponseFutureGenerator>(
        _ path: String,
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
        add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterGroup`
    /// - Parameter path: prefix to add to paths inside the group
    public func group(_ path: String = "") -> HBRouterGroup {
        return .init(path: path, router: self)
    }
}
