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

// MARK: - RouteController

/// A type that defines a body of routes.
///
/// You can create custom controllers by declaring types that conform to the `RouteController`
/// protocol. Implement the required ``RouteController/body`` computed property and provide a
/// type for the controller's `Context`.
///
///     struct UsersController {
///         typealias Context = BasicRouterRequestContext
///
///         var body: some RouterMiddleware<Context> {
///             RouteGroup("/users") {
///                 ...
///             }
///         }
///     }
///
/// Assemble the controller's body by combining one or more components together to create
/// a route. By nesting controllers within each other, you can compose large and complex
/// routes from smaller more mangeable components.
public protocol RouteController<Context> where Context == Body.Context {
    associatedtype Context: RouterRequestContext
    associatedtype Body: MiddlewareProtocol
    @MiddlewareFixedTypeBuilder<Body.Input, Body.Output, Body.Context> var body: Body { get }
}

// MARK: - MiddlewareFixedTypeBuilder + RouteController

/// Middleware stack result builder
///
/// Generates a middleware stack from the elements inside the result builder. The input,
/// context and output types passed through the middleware stack are fixed and cannot be changed.
extension MiddlewareFixedTypeBuilder {
    public static func buildExpression<C0: RouteController>(_ c0: C0) -> C0.Body where C0.Body.Input == Input, C0.Body.Output == Output, C0.Body.Context == Context {
        return c0.body
    }

    public static func buildBlock<C0: RouteController>(_ c0: C0) -> C0.Body {
        return c0.body
    }

    public static func buildPartialBlock<C0: RouteController>(first: C0) -> C0.Body {
        first.body
    }

    public static func buildPartialBlock<M0: MiddlewareProtocol, C0: RouteController>(
        accumulated m0: M0,
        next c0: C0
    ) -> _Middleware2<M0, C0.Body> where M0.Input == C0.Body.Input, M0.Output == C0.Body.Output, M0.Context == C0.Body.Context {
        _Middleware2(m0, c0.body)
    }
}

// MARK: - RouteBuilder + RouteController

extension RouteBuilder {
    public static func buildExpression<C0: RouteController>(_ c0: C0) -> C0.Body where C0.Body.Input == Request, C0.Body.Output == Response, C0.Body.Context == Context {
        c0.body
    }

    public static func buildPartialBlock<C0: RouteController>(first: C0) -> C0.Body {
        first.body
    }
}
