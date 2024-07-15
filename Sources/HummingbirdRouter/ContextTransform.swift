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

/// Router middleware that applies a middleware chain to URIs with a specified prefix
public struct ContextTransform<Context: RouterRequestContext, HandlerContext: RouterRequestContext, Handler: MiddlewareProtocol>: RouterMiddleware where Handler.Input == Request, Handler.Output == Response, Handler.Context == HandlerContext, HandlerContext.Source == Context {
    public typealias Input = Request
    public typealias Output = Response

    /// Group handler
    @usableFromInline
    let handler: Handler

    /// Create RouteGroup from result builder
    /// - Parameters:
    ///   - routerPath: Path local to group route this group is defined in
    ///   - builder: RouteGroup builder
    public init(
        context: HandlerContext.Type,
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
