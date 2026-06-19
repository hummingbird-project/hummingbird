//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import HummingbirdCore
import NIOCore

/// Internally used to transform RequestContext
struct TransformingRouterGroup<Context: RequestContext, Parent: RouterMethods<Context.Source>>: RouterMethods {
    typealias TransformContext = Context
    typealias InputContext = Context.Source
    let parent: Parent

    struct ContextTransformingResponder: HTTPResponder {
        typealias Context = InputContext
        let responder: any HTTPResponder<TransformContext>

        func respond(to request: Request, context: InputContext) async throws -> Response {
            let newContext = TransformContext(source: context)
            return try await self.responder.respond(to: request, context: newContext)
        }
    }

    init(parent: Parent) {
        self.parent = parent
    }

    /// Add middleware (Stub function as it isn't used)
    @discardableResult func add(middleware: any MiddlewareProtocol<Request, Response, Context>) -> Self {
        preconditionFailure("Cannot add middleware to TransformingRouterGroup")
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    @discardableResult func on<Responder: HTTPResponder>(
        _ path: RouterPath,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let transformResponder = ContextTransformingResponder(responder: responder)
        self.parent.on(path, method: method, responder: transformResponder)
        return self
    }
}

/// Internally used to transform RequestContext
struct ThrowingTransformingRouterGroup<Context: ChildRequestContext, Parent: RouterMethods<Context.ParentContext>>: RouterMethods {
    typealias TransformContext = Context
    typealias InputContext = Context.ParentContext
    let parent: Parent

    struct ContextTransformingResponder: HTTPResponder {
        typealias Context = InputContext
        let responder: any HTTPResponder<TransformContext>

        func respond(to request: Request, context: InputContext) async throws -> Response {
            let newContext = try TransformContext(context: context)
            return try await self.responder.respond(to: request, context: newContext)
        }
    }

    init(parent: Parent) {
        self.parent = parent
    }

    /// Add middleware (Stub function as it isn't used)
    @discardableResult func add(middleware: any MiddlewareProtocol<Request, Response, Context>) -> Self {
        preconditionFailure("Cannot add middleware to ThrowingTransformingRouterGroup")
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    @discardableResult func on<Responder: HTTPResponder>(
        _ path: RouterPath,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let transformResponder = ContextTransformingResponder(responder: responder)
        self.parent.on(path, method: method, responder: transformResponder)
        return self
    }
}

/// Internally used to transform RequestContext
struct TransformingMiddlewareRouterGroup<Context: RequestContext, Middleware: TransformingRouterMiddleware, Parent: RouterMethods>: RouterMethods
where Middleware.NextContext == Context, Middleware.Context == Parent.Context {
    struct ContextTransformingResponder: HTTPResponder {
        typealias Context = Middleware.Context
        let responder: any HTTPResponder<Middleware.NextContext>
        let middleware: Middleware

        func respond(to request: Request, context: Context) async throws -> Response {
            try await self.middleware.handle(request, context: context) { request, context in
                try await responder.respond(to: request, context: context)
            }
        }
    }
    let parent: Parent
    let middleware: Middleware

    init(parent: Parent, middleware: Middleware) {
        self.parent = parent
        self.middleware = middleware
    }

    /// Add middleware (Stub function as it isn't used)
    @discardableResult func add(middleware: any MiddlewareProtocol<Request, Response, Middleware.NextContext>) -> Self {
        preconditionFailure("Cannot add middleware to TransformingMiddlewareRouterGroup")
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    @discardableResult func on<Responder: HTTPResponder>(
        _ path: RouterPath,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let transformResponder = ContextTransformingResponder(responder: responder, middleware: self.middleware)
        self.parent.on(path, method: method, responder: transformResponder)
        return self
    }
}
