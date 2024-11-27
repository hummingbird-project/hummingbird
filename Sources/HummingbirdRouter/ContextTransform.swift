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

/// Router middleware that transforms the ``Hummingbird/RequestContext`` and uses it with the contained
/// Middleware chain
///
/// For the transform to work the `Source` of the transformed `RequestContext`` needs to be
/// the original `RequestContext` eg
/// ```
/// struct TransformedRequestContext {
///     typealias Source = BasicRequestContext
///     var coreContext: CoreRequestContextStorage
///     init(source: Source) {
///         self.coreContext = .init(source: source)
///     }
/// }
/// ```
public struct ContextTransform<Context: RouterRequestContext, HandlerContext: RouterRequestContext, Handler: MiddlewareProtocol>: RouterMiddleware
where Handler.Input == Request, Handler.Output == Response, Handler.Context == HandlerContext, HandlerContext.Source == Context {
    public typealias Input = Request
    public typealias Output = Response

    /// Group handler
    @usableFromInline
    let handler: Handler

    /// Create RouteGroup from result builder
    /// - Parameters:
    ///   - context: RequestContext to convert to
    ///   - builder: RouteGroup builder
    public init(
        to context: HandlerContext.Type,
        @MiddlewareFixedTypeBuilder<Request, Response, HandlerContext> builder: () -> Handler
    ) {
        self.handler = builder()
    }

    /// Process HTTP request and return an HTTP response
    /// - Parameters:
    ///   - input: Request
    ///   - context: Request context
    ///   - next: Next middleware to run, if no route handler is found
    /// - Returns: Response
    @inlinable
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        let handlerContext = Handler.Context(source: context)
        return try await self.handler.handle(input, context: handlerContext) { input, _ in
            try await next(input, context)
        }
    }
}

/// Router middleware that transforms the ``Hummingbird/RequestContext`` and uses it with the contained
/// Middleware chain. Used by ``HummingbirdRouter/RouteGroup/init(_:context:builder:)``
public struct ThrowingContextTransform<
    Context: RouterRequestContext,
    HandlerContext: RouterRequestContext & ChildRequestContext,
    Handler: MiddlewareProtocol
>: RouterMiddleware
where Handler.Input == Request, Handler.Output == Response, Handler.Context == HandlerContext, HandlerContext.ParentContext == Context {
    public typealias Input = Request
    public typealias Output = Response

    /// Group handler
    @usableFromInline
    let handler: Handler

    /// Create RouteGroup from result builder
    /// - Parameters:
    ///   - context: RequestContext to convert to
    ///   - builder: RouteGroup builder
    init(
        to context: HandlerContext.Type,
        @MiddlewareFixedTypeBuilder<Request, Response, HandlerContext> builder: () -> Handler
    ) {
        self.handler = builder()
    }

    /// Process HTTP request and return an HTTP response
    /// - Parameters:
    ///   - input: Request
    ///   - context: Request context
    ///   - next: Next middleware to run, if no route handler is found
    /// - Returns: Response
    @inlinable
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        let handlerContext = try Handler.Context(context: context)
        return try await self.handler.handle(input, context: handlerContext) { input, _ in
            try await next(input, context)
        }
    }
}
