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

/// Internally used to transform RequestContext
struct TransformingRouterGroup<InputContext: RequestContext, Context: RequestContext>: RouterMethods {
    typealias TransformContext = Context
    let parent: any RouterMethods<InputContext>
    let transform: @Sendable (Request, InputContext, (Request, TransformContext) async throws -> Response) async throws -> Response

    struct ContextTransformingResponder: HTTPResponder {
        typealias Context = InputContext
        let responder: any HTTPResponder<TransformContext>
        let transform: @Sendable (
            Request,
            InputContext,
            (Request, TransformContext) async throws -> Response
        ) async throws -> Response

        func respond(to request: Request, context: InputContext) async throws -> Response {
            try await transform(request, context) { req, context in
                try await self.responder.respond(to: request, context: context)
            }
        }
    }

    init(parent: any RouterMethods<InputContext>) where Context.Source == InputContext {
        self.parent = parent
        self.transform = { req, context, next in
            let context = TransformContext(source: context)
            return try await next(req, context)
        }
    }

    init(
        parent: any RouterMethods<InputContext>,
        middleware: some ContextTransformingMiddlewareProtocol<Request, Response, InputContext, Context>
    ) {
        self.parent = parent
        self.transform = middleware.handle
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
        let transformResponder = ContextTransformingResponder(
            responder: responder,
            transform: transform
        )
        self.parent.on(path, method: method, responder: transformResponder)
        return self
    }
}
