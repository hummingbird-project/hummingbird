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

public import Hummingbird

// MARK: - RouterController

/// A type that represents part of your app's middleware and routes
///
/// You create custom controllers by declaring types that conform to the `RouterController`
/// protocol. Implement the required ``RouterController/body-swift.property`` computed
/// property to provide the content for your custom controller.
///
///     struct MyController: RouterController {
///         typealias Context = BasicRouterRequestContext
///
///         var body: some RouterMiddleware<Context> {
///             Get("foo") { _,_ in "foo" }
///         }
///    }
///
/// Assemble the controller's body by combining one or more of the built-in controllers or middleware.
/// provided by Hummingbird, plus other custom controllers that you define, into a hierarchy of controllers.
public protocol RouterController<Context> {
    associatedtype Context
    associatedtype Body: RouterMiddleware<Context>
    @MiddlewareFixedTypeBuilder<Request, Response, Context> var body: Body { get }
}

// MARK: MiddlewareFixedTypeBuilder + RouterController Builders

extension MiddlewareFixedTypeBuilder {
    public static func buildExpression<C0: RouterController>(
        _ c0: C0
    ) -> C0.Body where C0.Body.Input == Input, C0.Body.Output == Output, C0.Body.Context == Context {
        c0.body
    }
}
