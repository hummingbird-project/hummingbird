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
    let router: HBRouterBuilder
    let middlewares: HBMiddlewareGroup

    init(path: String = "", middlewares: HBMiddlewareGroup = .init(), router: HBRouterBuilder) {
        self.path = path
        self.router = router
        self.middlewares = middlewares
    }

    /// Add middleware to RouterEndpoint
    @discardableResult public func add(middleware: HBMiddleware) -> HBRouterGroup {
        self.middlewares.add(middleware)
        return self
    }

    /// Return a group inside the current group
    /// - Parameter path: path prefix to add to routes inside this group
    @discardableResult public func group(_ path: String = "") -> HBRouterGroup {
        return HBRouterGroup(
            path: self.combinePaths(self.path, path),
            middlewares: .init(middlewares: self.middlewares.middlewares),
            router: self.router
        )
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) throws -> Output
    ) -> Self {
        let responder = Self.constructResponder(options: options, use: closure)
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    /// Add path for closure returning type conforming to ResponseFutureEncodable
    @discardableResult public func on<Output: HBResponseGenerator>(
        _ path: String = "",
        method: HTTPMethod,
        options: HBRouterMethodOptions = [],
        use closure: @escaping (HBRequest) -> EventLoopFuture<Output>
    ) -> Self {
        let responder = Self.constructResponder(options: options, use: closure)
        let path = self.combinePaths(self.path, path)
        self.router.add(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }

    internal func combinePaths(_ path1: String, _ path2: String) -> String {
        let path1 = path1.dropSuffix("/")
        let path2 = path2.dropPrefix("/")
        return "\(path1)/\(path2)"
    }
}
