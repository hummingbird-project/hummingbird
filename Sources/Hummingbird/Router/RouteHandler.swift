//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import MiddlewareModule
import ServiceContextModule

/// Protocol for route handler object. 
/// 
/// Requires a function that returns a response from a request and context
public protocol RouteHandlerProtocol<Context>: Sendable {
    associatedtype Context: HBRequestContext
    func handle(_ request: HBRequest, context: Context) async throws -> HBResponse
}

/// Implementatinon of RouteHandleProtocol that uses a closure to produce a response
public struct RouteHandlerClosure<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteHandlerProtocol {
    @usableFromInline
    let closure: @Sendable (HBRequest, Context) async throws -> RouteOutput

    @inlinable
    public func handle(_ request: HBRequest, context: Context) async throws -> HBResponse {
        try await closure(request, context).response(from: request, context: context)
    }
}

/// Implementatinon of RouteHandleProtocol that uses a MiddlewareStack to produce a resposne 
public struct RouteHandlerMiddleware<M0: MiddlewareProtocol>: RouteHandlerProtocol where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context: HBRequestContext {
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
        try await middleware.handle(request, context: context, next: Self.notFound)
    }
}
