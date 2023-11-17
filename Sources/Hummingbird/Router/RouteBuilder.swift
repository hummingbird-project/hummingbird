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

/// Route Handler Middleware.
/// 
/// Requires that the return value of handler conforms to ``HBResponseGenerator`` so 
/// that the `handle` function can return an `HBResponse`
public struct Handle<HandlerOutput: HBResponseGenerator, Context: HBRequestContext>: Sendable, MiddlewareProtocol {
    public typealias Input = HBRequest
    public typealias Output = HBResponse
    public typealias Handler = @Sendable (Input, Context) async throws -> HandlerOutput

    let handler: Handler

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        return try await self.handler(input, context).response(from: input, context: context)
    }
}

/// Result builder for a Route.
/// 
/// This is very similar to the ``MiddlewareStack`` reult builder except it requires the
/// last entry of the builder to be a ``Handle`` so we are guaranteed a Response. It also 
/// adds the ability to pass in a closure instead of ``Handle`` type.
@resultBuilder
public enum RouteBuilder<Context: HBRequestContext> {
    /// Provide generic requirements for MiddlewareProtocol 
    public static func buildExpression<M0: MiddlewareProtocol>(_ m0: M0) -> M0 where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
        return m0
    }

    /// Build a ``Handle`` from a closure 
    public static func buildExpression<HandlerOutput: HBResponseGenerator>(_ handler: @escaping @Sendable (HBRequest, Context) async throws -> HandlerOutput) -> Handle<HandlerOutput, Context> {
        return .init(handler)
    }

    public static func buildPartialBlock<M0: MiddlewareProtocol>(first: M0) -> M0 {
        first
    }

    public static func buildPartialBlock<M0: MiddlewareProtocol, M1: MiddlewareProtocol>(
        accumulated m0: M0,
        next m1: M1
    ) -> _Middleware2<M0, M1> where M0.Input == M1.Input, M0.Output == M1.Output, M0.Context == M1.Context {
        _Middleware2(m0, m1)
    }

    /// Build the final result where the input is a single ``Handle`` middleware
    public static func buildFinalResult<RouteOutput: HBResponseGenerator>(_ m0: Handle<RouteOutput, Context>) -> Handle<RouteOutput, Context> {
        m0
    }

    /// Build the final result where input is multiple middleware with the final middleware being a ``Handle`` middleware.
    public static func buildFinalResult<M0: MiddlewareProtocol, RouteOutput: HBResponseGenerator>(_ m0: _Middleware2<M0, Handle<RouteOutput, M0.Context>>) -> _Middleware2<M0, Handle<RouteOutput, M0.Context>> {
        m0
    }
}
