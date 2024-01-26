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

import HTTPTypes
import HummingbirdCore
import NIOCore

/// Create rules for routing requests and then create `HBResponder` that will follow these rules.
///
/// `HBRouter` requires an implementation of  the `on(path:method:use)` functions but because it
/// also conforms to `HBRouterMethods` it is also possible to call the method specific functions `get`, `put`,
/// `head`, `post` and `patch`.  The route handler closures all return objects conforming to
/// `HBResponseGenerator`.  This allows us to support routes which return a multitude of types eg
/// ```
/// router.get("string") { _, _ -> String in
///     return "string"
/// }
/// router.post("status") { _, _ -> HTTPResponseStatus in
///     return .ok
/// }
/// router.data("data") { request, context -> ByteBuffer in
///     return context.allocator.buffer(string: "buffer")
/// }
/// ```
///
/// The default `Router` setup in `HBApplication` is the `TrieRouter` . This uses a
/// trie to partition all the routes for faster access. It also supports wildcards and parameter extraction
/// ```
/// router.get("user/*", use: anyUser)
/// router.get("user/:id", use: userWithId)
/// ```
/// Both of these match routes which start with "/user" and the next path segment being anything.
/// The second version extracts the path segment out and adds it to `HBRequest.parameters` with the
/// key "id".
public final class HBRouter<Context: HBBaseRequestContext>: HBRouterMethods, HBResponderBuilder {
    var trie: RouterPathTrieBuilder<HBEndpointResponders<Context>>
    public let middlewares: HBMiddlewareGroup<Context>

    public init(context: Context.Type = HBBasicRequestContext.self) {
        self.trie = RouterPathTrieBuilder()
        self.middlewares = .init()
    }

    /// Add route to router
    /// - Parameters:
    ///   - path: URI path
    ///   - method: http method
    ///   - responder: handler to call
    public func add(_ path: String, method: HTTPRequest.Method, responder: any HBResponder<Context>) {
        // ensure path starts with a "/" and doesn't end with a "/"
        let path = "/\(path.dropSuffix("/").dropPrefix("/"))"
        self.trie.addEntry(.init(path), value: HBEndpointResponders(path: path)) { node in
            node.value!.addResponder(for: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        }
    }

    /// build responder from router
    public func buildResponder() -> HBRouterResponder<Context> {
        HBRouterResponder(context: Context.self, trie: self.trie.build(), notFoundResponder: self.middlewares.constructResponder(finalResponder: NotFoundResponder<Context>()))
    }

    /// Add path for closure returning type conforming to HBResponseGenerator
    @discardableResult public func on(
        _ path: String,
        method: HTTPRequest.Method,
        use closure: @escaping @Sendable (HBRequest, Context) async throws -> some HBResponseGenerator
    ) -> Self {
        let responder = constructResponder(use: closure)
        self.add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterGroup`
    /// - Parameter path: prefix to add to paths inside the group
    public func group(_ path: String = "") -> HBRouterGroup<Context> {
        return .init(path: path, router: self)
    }
}

/// Responder that return a not found error
struct NotFoundResponder<Context: HBBaseRequestContext>: HBResponder {
    func respond(to request: HBRequest, context: Context) throws -> HBResponse {
        throw HBHTTPError(.notFound)
    }
}

/// A type that has a single method to build a responder
public protocol HBResponderBuilder {
    associatedtype Responder: HBResponder
    /// build a responder
    func buildResponder() -> Responder
}
