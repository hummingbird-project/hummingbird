//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes
public import HummingbirdCore

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
@available(iOS 16, *)
public struct RouterGroup<Context: RequestContext>: RouterMethods {
    let path: RouterPath
    let parent: any RouterMethods<Context>
    let middlewares: MiddlewareGroup<Context>

    init(path: RouterPath = "", parent: any RouterMethods<Context>) {
        self.path = path
        self.parent = parent
        self.middlewares = .init()
    }

    /// Add middleware to RouterGroup
    ///
    /// This middleware will only be applied to endpoints added after this call.
    /// - Parameter middleware: Middleware we are adding
    @discardableResult public func add(middleware: any MiddlewareProtocol<Request, Response, Context>) -> RouterGroup<Context> {
        self.middlewares.add(middleware)
        return self
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    @discardableResult public func on<Responder: HTTPResponder>(
        _ path: RouterPath,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let path = self.path.appendingPath(path)
        self.parent.on(path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        return self
    }
}
