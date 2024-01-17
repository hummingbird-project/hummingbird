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
    associatedtype Context: HBRouterRequestContext
    func handle(_ request: HBRequest, context: Context) async throws -> HBResponse
}

/// Implementatinon of ``_RouteHandlerProtocol`` that uses a closure to produce a response.
///
/// This is used internally to implement `Route` when it is initialized with a closure.
@_documentation(visibility: internal)
public struct _RouteHandlerClosure<RouteOutput: HBResponseGenerator, Context: HBRouterRequestContext>: _RouteHandlerProtocol {
    @usableFromInline
    let closure: @Sendable (HBRequest, Context) async throws -> RouteOutput

    @inlinable
    public func handle(_ request: HBRequest, context: Context) async throws -> HBResponse {
        try await self.closure(request, context).response(from: request, context: context)
    }
}

/// Implementatinon of ``_RouteHandlerProtocol`` that uses a MiddlewareStack to produce a resposne
///
/// This is used internally to implement `Route` when it is initialized with a middleware built
/// from the ``RouteBuilder`` result builder.
@_documentation(visibility: internal)
public struct _RouteHandlerMiddleware<M0: MiddlewareProtocol>: _RouteHandlerProtocol where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context: HBRouterRequestContext {
    public typealias Context = M0.Context

    /// Dummy function passed to middleware handle
    @usableFromInline
    static func notFound(_: HBRequest, _: Context) -> HBResponse {
        .init(status: .notFound)
    }

    @usableFromInline
    let middleware: M0

    @inlinable
    public func handle(_ request: HBRequest, context: Context) async throws -> HBResponse {
        try await self.middleware.handle(request, context: context, next: Self.notFound)
    }
}
