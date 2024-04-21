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
        self.routes[.init(path: path, method: method)] = responder
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

    fileprivate struct RouteDefinition: Hashable {
        let path: String
        let method: HTTPRequest.Method
    }

    fileprivate var routes: [RouteDefinition: any HTTPResponder<Context>]
    let middlewares: MiddlewareGroup<Context>
}

extension RouterMethods {
    /// Add route collection to router
    /// - Parameter collection: Route collection
    public func add(_ path: String = "", routes collection: RouteCollection<Context>) {
        for (definition, responder) in collection.routes {
            // ensure path starts with a "/" and doesn't end with a "/"
            let path = self.combinePaths(path, definition.path)
            self.on(path, method: definition.method, responder: collection.middlewares.constructResponder(finalResponder: responder))
        }
    }
}
