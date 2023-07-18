//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import NIOCore
import NIOHTTP1

/// Create rules for routing requests and then create `HBResponder` that will follow these rules.
///
/// `HBRouterBuilder` requires an implementation of  the `on(path:method:use)` functions but because it
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
public final class HBRouterBuilder: HBRouterMethods {
    var trie: RouterPathTrie<HBEndpointResponders>
    public let middlewares: HBMiddlewareGroup

    public init() {
        self.trie = RouterPathTrie()
        self.middlewares = .init()
    }

    /// Add route to router
    /// - Parameters:
    ///   - path: URI path
    ///   - method: http method
    ///   - responder: handler to call
    public func add(_ path: String, method: HTTPMethod, responder: HBResponder) {
        // ensure path starts with a "/" and doesn't end with a "/"
        let path = "/\(path.dropSuffix("/").dropPrefix("/"))"
        self.trie.addEntry(.init(path), value: HBEndpointResponders(path: path)) { node in
            node.value!.addResponder(for: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        }
    }

    func endpoint(_ path: String) -> HBEndpointResponders? {
        self.trie.getValueAndParameters(path)?.value
    }

    /// build router
    public func buildRouter() -> HBResponder {
        HBRouter(trie: self.trie, notFoundResponder: self.middlewares.constructResponder(finalResponder: NotFoundResponder()))
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) throws -> Output
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        self.add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        self.add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterGroup`
    /// - Parameter path: prefix to add to paths inside the group
    public func group(_ path: String = "") -> HBRouterGroup {
        return .init(path: path, router: self)
    }
}

/// Responder that return a not found error
struct NotFoundResponder: HBResponder {
    func respond(to request: HBRequest) -> NIOCore.EventLoopFuture<HBResponse> {
        return request.eventLoop.makeFailedFuture(HBHTTPError(.notFound))
    }
}
