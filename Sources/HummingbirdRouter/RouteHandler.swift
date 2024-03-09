//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird

/// Protocol for route handler object.
///
/// Requires a function that returns a HTTP response from a HTTP request and context.
@_documentation(visibility: internal)
public protocol _RouteHandlerProtocol<Context>: Sendable {
    associatedtype Context: RouterRequestContext
    func handle(_ request: Request, context: Context) async throws -> Response
}

/// Implementatinon of ``_RouteHandlerProtocol`` that uses a closure to produce a response.
///
/// This is used internally to implement `Route` when it is initialized with a closure.
@_documentation(visibility: internal)
public struct _RouteHandlerClosure<RouteOutput: ResponseGenerator, Context: RouterRequestContext>: _RouteHandlerProtocol {
    @usableFromInline
    let closure: @Sendable (Request, Context) async throws -> RouteOutput

    @inlinable
    public func handle(_ request: Request, context: Context) async throws -> Response {
        try await self.closure(request, context).response(from: request, context: context)
    }
}

/// Implementatinon of ``_RouteHandlerProtocol`` that uses a MiddlewareStack to produce a resposne
///
/// This is used internally to implement `Route` when it is initialized with a middleware built
/// from the ``RouteBuilder`` result builder.
@_documentation(visibility: internal)
public struct _RouteHandlerMiddleware<M0: MiddlewareProtocol>: _RouteHandlerProtocol where M0.Input == Request, M0.Output == Response, M0.Context: RouterRequestContext {
    public typealias Context = M0.Context

    /// Dummy function passed to middleware handle
    @usableFromInline
    static func notFound(_: Request, _: Context) -> Response {
        .init(status: .notFound)
    }

    @usableFromInline
    let middleware: M0

    @inlinable
    public func handle(_ request: Request, context: Context) async throws -> Response {
        try await self.middleware.handle(request, context: context, next: Self.notFound)
    }
}
