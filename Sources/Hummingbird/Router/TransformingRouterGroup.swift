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

/// Used to group together routes using a new ``RequestContext`` under a single path. Additional
/// middleware can be added to the endpoint and each route can add a suffix to the endpoint path
///
/// The code below creates an `RouterGroup`with path "todos" and adds GET and PUT routes on "todos"
/// and adds GET, PUT and DELETE routes on "todos/:id" where id is the identifier for the todo
///
/// The new Context's ``RequestContext.Source`` needs to be he context of the group parent so the
/// the new context can be initialized from the context of the parent.
/// ```
/// router
/// .transformingGroup("todos", context: MyContext.self)
/// .get(use: todoController.list)
/// .put(use: todoController.create)
/// .get(":id", use: todoController.get)
/// .put(":id", use: todoController.update)
/// .delete(":id", use: todoController.delete)
/// ```
public struct TransformingRouterGroup<InputContext: RequestContext, Context: RequestContext>: RouterMethods {
    let path: RouterPath
    let parent: any RouterMethods<InputContext>
    let middlewares: MiddlewareGroup<Context>
    let convertContext: @Sendable (InputContext) -> Context

    struct ContextTransformingResponder: HTTPResponder {
        let responder: any HTTPResponder<Context>
        let convertContext: @Sendable (InputContext) -> Context

        public func respond(to request: Request, context: InputContext) async throws -> Response {
            let newContext = self.convertContext(context)
            return try await self.responder.respond(to: request, context: newContext)
        }
    }

    init(
        path: RouterPath = "",
        parent: any RouterMethods<InputContext>,
        convertContext: @escaping @Sendable (InputContext) -> Context
    ) {
        self.path = path
        self.parent = parent
        self.middlewares = .init()
        self.convertContext = convertContext
    }

    /// Add middleware to RouterGroup
    @discardableResult public func add(middleware: any RouterMiddleware<Context>) -> Self {
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
        let groupResponder = self.middlewares.constructResponder(finalResponder: responder)
        let transformResponder = ContextTransformingResponder(responder: groupResponder, convertContext: self.convertContext)
        self.parent.on(path, method: method, responder: transformResponder)
        return self
    }
}
