//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes

/// Collection of routes
public final class RouteCollection<Context: BaseRequestContext>: RouterMethods {
    /// Initialize RouteCollection
    public init(context: Context.Type = BasicRequestContext.self) {
        self.routes = .init()
        self.middlewares = .init()
    }

    /// Add responder to call when path and method are matched
    ///
    /// - Parameters:
    ///   - path: Path to match
    ///   - method: Request method to match
    ///   - responder: Responder to call if match is made
    /// - Returns: self
    public func on<Responder: HTTPResponder>(
        _ path: String,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let route = RouteDefinition(path: path, method: method, responder: responder)
        self.routes.append(route)
        return self
    }

    /// Return a group inside the route collection
    /// - Parameter path: path prefix to add to routes inside this group
    public func group(_ path: String = "") -> RouterGroup<Context> {
        return .init(path: path, router: self)
    }

    /// Add middleware to RouteCollection
    @discardableResult public func add(middleware: any RouterMiddleware<Context>) -> Self {
        self.middlewares.add(middleware)
        return self
    }

    fileprivate struct RouteDefinition {
        let path: String
        let method: HTTPRequest.Method
        let responder: any HTTPResponder<Context>
    }

    fileprivate var routes: [RouteDefinition]
    let middlewares: MiddlewareGroup<Context>
}

extension RouterMethods {
    /// Add route collection to router
    /// - Parameter collection: Route collection
    public func addRoutes(_ collection: RouteCollection<Context>, atPath path: String = "") {
        for route in collection.routes {
            // ensure path starts with a "/" and doesn't end with a "/"
            let path = self.combinePaths(path, route.path)
            self.on(path, method: route.method, responder: collection.middlewares.constructResponder(finalResponder: route.responder))
        }
    }
}
