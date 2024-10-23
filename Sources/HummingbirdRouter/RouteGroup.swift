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
public struct RouteGroup<Context: RouterRequestContext, Handler: MiddlewareProtocol>: RouterMiddleware where Handler.Input == Request, Handler.Output == Response, Handler.Context == Context {
    public typealias Input = Request
    public typealias Output = Response

    /// Full URI path to route
    @usableFromInline
    let fullPath: RouterPath
    /// Path local to group route this group is defined in.
    @usableFromInline
    let routerPath: RouterPath
    /// Group handler
    @usableFromInline
    let handler: Handler

    /// Create RouteGroup from result builder
    /// - Parameters:
    ///   - routerPath: Path local to group route this group is defined in
    ///   - builder: RouteGroup builder
    public init(
        _ routerPath: RouterPath,
        @MiddlewareFixedTypeBuilder<Request, Response, Context> builder: () -> Handler
    ) {
        var routerPath = routerPath
        // Get builder state from service context
        var routerBuildState = RouterBuilderState.current ?? .init(options: [])
        if routerBuildState.options.contains(.caseInsensitive) {
            routerPath = routerPath.lowercased()
        }
        let parentGroupPath = routerBuildState.routeGroupPath
        self.fullPath = parentGroupPath.appendingPath(routerPath)
        routerBuildState.routeGroupPath = self.fullPath
        self.handler = RouterBuilderState.$current.withValue(routerBuildState) {
            builder()
        }
        self.routerPath = routerPath
    }

    /// Create RouteGroup that transforms the RequestContext from result builder
    /// - Parameters:
    ///   - routerPath: Path local to group route this group is defined in
    ///   - context: RequestContext to convert to
    ///   - builder: RouteGroup builder
    ///
    /// The RequestContext that the group uses must conform to ``Hummingbird/ChildRequestContext`` eg
    /// ```
    /// struct TransformedRequestContext: ChildRequestContext {
    ///     typealias ParentContext = BasicRequestContext
    ///     var coreContext: CoreRequestContextStorage
    ///     init(context: ParentContext) throws {
    ///         self.coreContext = .init(source: context)
    ///     }
    /// }
    /// ```
    public init<ChildHandler: MiddlewareProtocol, ChildContext: ChildRequestContext & RouterRequestContext>(
        _ routerPath: RouterPath,
        context: ChildContext.Type,
        @MiddlewareFixedTypeBuilder<Request, Response, ChildContext> builder: () -> ChildHandler
    ) where ChildContext == ChildContext, Handler == ThrowingContextTransform<Context, ChildContext, ChildHandler> {
        var routerPath = routerPath
        // Get builder state from service context
        var routerBuildState = RouterBuilderState.current ?? .init(options: [])
        if routerBuildState.options.contains(.caseInsensitive) {
            routerPath = routerPath.lowercased()
        }
        let parentGroupPath = routerBuildState.routeGroupPath
        self.fullPath = parentGroupPath.appendingPath(routerPath)
        routerBuildState.routeGroupPath = self.fullPath
        self.handler = RouterBuilderState.$current.withValue(routerBuildState) {
            ThrowingContextTransform(to: ChildHandler.Context.self, builder: builder)
        }
        self.routerPath = routerPath
    }

    /// Process HTTP request and return an HTTP response
    /// - Parameters:
    ///   - input: Request
    ///   - context: Request context
    ///   - next: Next middleware to run, if no route handler is found
    /// - Returns: Response
    @inlinable
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        if let updatedContext = self.routerPath.matchPrefix(context) {
            context.coreContext.endpointPath.value = self.fullPath.description
            return try await self.handler.handle(input, context: updatedContext) { input, _ in
                try await next(input, context)
            }
        }
        return try await next(input, context)
    }
}
