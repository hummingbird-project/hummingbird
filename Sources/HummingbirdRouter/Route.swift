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

import HTTPTypes
import Hummingbird
import ServiceContextModule

/// Route definition
public struct Route<Handler: RouteHandlerProtocol, Context: HBRouterRequestContext>: HBMiddlewareProtocol where Handler.Context == Context {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPRequest.Method
    public let handler: Handler

    /// Initialize Route
    /// - Parameters:
    ///   - method: Route method
    ///   - routerPath: Route path, relative to Group route is defined in
    ///   - handler: Route handler
    init(_ method: HTTPRequest.Method, _ routerPath: RouterPath = "", handler: Handler) {
        self.method = method
        self.routerPath = routerPath
        self.handler = handler
        self.fullPath = Self.getFullPath(from: routerPath)
    }

    /// Initialize Route with a closure
    /// - Parameters:
    ///   - method: Route method
    ///   - routerPath: Route path, relative to Group route is defined in
    ///   - handler: Router handler closure
    public init<RouteOutput: HBResponseGenerator>(
        _ method: HTTPRequest.Method,
        _ routerPath: RouterPath = "",
        handler: @escaping @Sendable (Input, Context) async throws -> RouteOutput
    ) where Handler == RouteHandlerClosure<RouteOutput, Context> {
        self.init(
            method,
            routerPath,
            handler: RouteHandlerClosure(closure: handler)
        )
    }

    /// Initialize Route with a MiddlewareProtocol
    /// - Parameters:
    ///   - method: Route method
    ///   - routerPath: Route path, relative to Group route is defined in
    ///   - builder: Result builder used to build Route middleware
    public init<M0: MiddlewareProtocol>(
        _ method: HTTPRequest.Method,
        _ routerPath: RouterPath = "",
        @RouteBuilder<Context> builder: () -> M0
    ) where Handler == RouteHandlerMiddleware<M0>, M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
        self.init(
            method,
            routerPath,
            handler: RouteHandlerMiddleware(middleware: builder())
        )
    }

    /// Handle route middleware
    /// - Parameters:
    ///   - input: Request
    ///   - context: Context for handler
    ///   - next: Next middleware to call if route method and path is not matched
    /// - Returns: Response
    public func handle(_ input: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
        if input.method == self.method, let context = self.routerPath.matchAll(context) {
            context.coreContext.endpointPath.value = self.fullPath
            return try await self.handler.handle(input, context: context)
        }
        return try await next(input, context)
    }

    /// Return full path of route, using Task local stored `routeGroupPath`.
    static func getFullPath(from path: RouterPath) -> String {
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        if path.count > 0 || parentGroupPath.count == 0 {
            return "\(parentGroupPath)/\(path)"
        } else {
            return parentGroupPath
        }
    }
}

/// Create a GET Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Get<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.get, routerPath, handler: handler)
}

/// Create a GET Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Get<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.get, routerPath, builder: builder)
}

/// Create a HEAD Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Head<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.head, routerPath, handler: handler)
}

/// Create a HEAD Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Head<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.head, routerPath, builder: builder)
}

/// Create a PUT Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Put<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.put, routerPath, handler: handler)
}

/// Create a PUT Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Put<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.put, routerPath, builder: builder)
}

/// Create a POST Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Post<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.post, routerPath, handler: handler)
}

/// Create a POST Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Post<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.post, routerPath, builder: builder)
}

/// Create a PATCH Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Patch<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.patch, routerPath, handler: handler)
}

/// Create a PATCH Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Patch<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.patch, routerPath, builder: builder)
}

/// Create a DELETE Route with a closure
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - handler: Router handler closure
public func Delete<RouteOutput: HBResponseGenerator, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    handler: @escaping @Sendable (HBRequest, Context) async throws -> RouteOutput
) -> Route<RouteHandlerClosure<RouteOutput, Context>, Context> {
    .init(.delete, routerPath, handler: handler)
}

/// Create a DELETE Route with a MiddlewareProtocol
/// - Parameters:
///   - routerPath: Route path, relative to Group route is defined in
///   - builder: Result builder used to build Route middleware
public func Delete<M0: MiddlewareProtocol, Context: HBRequestContext>(
    _ routerPath: RouterPath = "",
    @RouteBuilder<Context> builder: () -> M0
) -> Route<RouteHandlerMiddleware<M0>, Context> where M0.Input == HBRequest, M0.Output == HBResponse, M0.Context == Context {
    .init(.delete, routerPath, builder: builder)
}
