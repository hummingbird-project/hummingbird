//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import Hummingbird

/// Route Handler Middleware.
///
/// Requires that the return value of handler conforms to ``Hummingbird/ResponseGenerator`` so
/// that the `handle` function can return an ``HummingbirdCore/Response``
public struct Handle<HandlerOutput: ResponseGenerator, Context: RouterRequestContext>: Sendable, MiddlewareProtocol {
    public typealias Input = Request
    public typealias Output = Response
    public typealias Handler = @Sendable (Input, Context) async throws -> HandlerOutput

    let handler: Handler

    ///  Initialize a Handle route middleware
    /// - Parameter handler: Handler function used to process HTTP request
    public init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    /// Process HTTP request and return an HTTP response
    /// - Parameters:
    ///   - input: Request
    ///   - context: Request context
    ///   - next: Next middleware to run, if no route handler is found
    /// - Returns: Response
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        try await self.handler(input, context).response(from: input, context: context)
    }
}

/// Result builder for a Route.
///
/// This is very similar to the ``Hummingbird/MiddlewareFixedTypeBuilder`` result builder except it requires
/// the last entry of the builder to be a ``Handle`` so we are guaranteed a Response. It also
/// adds the ability to pass in a closure instead of ``Handle`` type.
@resultBuilder
public enum RouteBuilder<Context: RouterRequestContext> {
    /// Provide generic requirements for MiddlewareProtocol
    public static func buildExpression<M0: MiddlewareProtocol>(
        _ m0: M0
    ) -> M0 where M0.Input == Request, M0.Output == Response, M0.Context == Context {
        m0
    }

    /// Build a ``Handle`` from a closure
    public static func buildExpression<HandlerOutput: ResponseGenerator>(
        _ handler: @escaping @Sendable (Request, Context) async throws -> HandlerOutput
    ) -> Handle<HandlerOutput, Context> {
        .init(handler)
    }

    public static func buildBlock<RouteOutput: ResponseGenerator>(_ m0: Handle<RouteOutput, Context>) -> Handle<RouteOutput, Context> {
        m0
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
    public static func buildFinalResult<RouteOutput: ResponseGenerator>(_ m0: Handle<RouteOutput, Context>) -> Handle<RouteOutput, Context> {
        m0
    }

    /// Build the final result where input is multiple middleware with the final middleware being a ``Handle`` middleware.
    public static func buildFinalResult<M0: MiddlewareProtocol, RouteOutput: ResponseGenerator>(
        _ m0: _Middleware2<M0, Handle<RouteOutput, M0.Context>>
    ) -> _Middleware2<M0, Handle<RouteOutput, M0.Context>> {
        m0
    }
}
