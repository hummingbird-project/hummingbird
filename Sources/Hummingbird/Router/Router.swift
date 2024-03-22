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

/// Create rules for routing requests and then create `Responder` that will follow these rules.
///
/// `Router` requires an implementation of  the `on(path:method:use)` functions but because it
/// also conforms to `RouterMethods` it is also possible to call the method specific functions `get`, `put`,
/// `head`, `post` and `patch`.  The route handler closures all return objects conforming to
/// `ResponseGenerator`.  This allows us to support routes which return a multitude of types eg
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
/// The default `Router` setup in `Application` is the `TrieRouter` . This uses a
/// trie to partition all the routes for faster access. It also supports wildcards and parameter extraction
/// ```
/// router.get("user/*", use: anyUser)
/// router.get("user/:id", use: userWithId)
/// ```
/// Both of these match routes which start with "/user" and the next path segment being anything.
/// The second version extracts the path segment out and adds it to `Request.parameters` with the
/// key "id".
public final class Router<Context: BaseRequestContext>: RouterMethods, HTTPResponderBuilder {
    var trie: RouterPathTrieBuilder<EndpointResponders<Context>>
    public let middlewares: MiddlewareGroup<Context>
    let options: RouterOptions

    public init(context: Context.Type = BasicRequestContext.self, options: RouterOptions = []) {
        self.trie = RouterPathTrieBuilder()
        self.middlewares = .init()
        self.options = options
    }

    /// Add route to router
    /// - Parameters:
    ///   - path: URI path
    ///   - method: http method
    ///   - responder: handler to call
    public func add(_ path: String, method: HTTPRequest.Method, responder: any HTTPResponder<Context>) {
        // ensure path starts with a "/" and doesn't end with a "/"
        let path = "/\(path.dropSuffix("/").dropPrefix("/"))"
        self.trie.addEntry(.init(path), value: EndpointResponders(path: path)) { node in
            node.value!.addResponder(for: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        }
    }

    /// build responder from router
    public func buildResponder() -> BinaryRouterResponder<Context> {
        if self.options.contains(.autoGenerateHeadEndpoints) {
            self.trie.forEach { node in
                node.value?.autoGenerateHeadEndpoint()
            }
        }
        return try! .init(
            context: Context.self,
            trie: self.trie.build(),
            options: self.options,
            notFoundResponder: self.middlewares.constructResponder(finalResponder: NotFoundResponder<Context>())
        )
    }

    /// Add path for closure returning type conforming to ResponseGenerator
    @discardableResult public func on(
        _ path: String,
        method: HTTPRequest.Method,
        use closure: @escaping @Sendable (Request, Context) async throws -> some ResponseGenerator
    ) -> Self {
        let responder = constructResponder(use: closure)
        var path = path
        if self.options.contains(.caseInsensitive) {
            path = path.lowercased()
        }
        self.add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterGroup`
    /// - Parameter path: prefix to add to paths inside the group
    public func group(_ path: String = "") -> RouterGroup<Context> {
        return .init(path: path, router: self)
    }
}

/// Responder that return a not found error
struct NotFoundResponder<Context: BaseRequestContext>: HTTPResponder {
    func respond(to request: Request, context: Context) throws -> Response {
        throw HTTPError(.notFound)
    }
}

/// A type that has a single method to build a HTTPResponder
public protocol HTTPResponderBuilder {
    associatedtype Responder: HTTPResponder
    /// build a responder
    func buildResponder() -> Responder
}

/// Router Options
public struct RouterOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Router path comparisons will be case insensitive
    public static var caseInsensitive: Self { .init(rawValue: 1 << 0) }
    /// For every GET request that does not have a HEAD request, auto generate the HEAD request
    public static var autoGenerateHeadEndpoints: Self { .init(rawValue: 1 << 1) }
}
