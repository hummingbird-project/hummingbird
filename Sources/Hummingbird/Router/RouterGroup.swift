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

/// Used to group together routes under a single path. Additional middleware can be added to the endpoint and each route can add a
/// suffix to the endpoint path
///
/// The code below creates an `RouterGroup`with path "todos" and adds GET and PUT routes on "todos" and adds GET, PUT and
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
public struct RouterGroup<Context: BaseRequestContext>: RouterMethods {
    let path: String
    let router: any RouterMethods<Context>
    let middlewares: MiddlewareGroup<Context>

    init(path: String = "", middlewares: MiddlewareGroup<Context> = .init(), router: any RouterMethods<Context>) {
        self.path = path
        self.router = router
        self.middlewares = middlewares
    }

    /// Add middleware to RouterGroup
    @discardableResult public func add(middleware: any RouterMiddleware<Context>) -> RouterGroup<Context> {
        self.middlewares.add(middleware)
        return self
    }

    /// Return a group inside the current group
    /// - Parameter path: path prefix to add to routes inside this group
    @discardableResult public func group(_ path: String = "") -> RouterGroup<Context> {
        return RouterGroup(
            path: self.combinePaths(self.path, path),
            middlewares: .init(middlewares: self.middlewares.middlewares),
            router: self.router
        )
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    @discardableResult public func on<Responder: HTTPResponder>(
        _ path: String,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        // ensure path starts with a "/" and doesn't end with a "/"
        let path = self.combinePaths(self.path, path)
        self.router.on(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}
