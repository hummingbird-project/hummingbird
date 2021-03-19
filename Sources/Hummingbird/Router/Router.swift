//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) throws -> Output
    ) -> Self {
        let responder = constructResponder(options: options, use: closure)
        add(path, method: method, responder: responder)
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
        add(path, method: method, responder: responder)
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String,
        method: HTTPMethod,
        body: HBBodyCollation = .collate,
        use closure: @escaping (HBRequest) async throws -> Output
    ) -> Self {
        let responder = constructResponder(body: body, use: closure)
        add(path, method: method, responder: responder)
        return self
    }

    /// return new `RouterGroup`
    /// - Parameter path: prefix to add to paths inside the group
    public func group(_ path: String = "") -> HBRouterGroup {
        return .init(path: path, router: self)
    }
}
