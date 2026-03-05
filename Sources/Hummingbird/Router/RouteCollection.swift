//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes

/// Collection of routes
@available(macOS 14, iOS 17, tvOS 17, *)
public final class RouteCollection<Context: RequestContext>: RouterMethods {
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
        _ path: RouterPath,
        method: HTTPRequest.Method,
        responder: Responder
    ) -> Self where Responder.Context == Context {
        let route = RouteDefinition(path: path, method: method, responder: self.middlewares.constructResponder(finalResponder: responder))
        self.routes.append(route)
        return self
    }

    /// Add middleware to RouteCollection
    ///
    /// This middleware will only be applied to endpoints added after this call.
    /// - Parameter middleware: Middleware we are adding
    @discardableResult public func add(middleware: any MiddlewareProtocol<Request, Response, Context>) -> Self {
        self.middlewares.add(middleware)
        return self
    }

    fileprivate struct RouteDefinition {
        let path: RouterPath
        let method: HTTPRequest.Method
        let responder: any HTTPResponder<Context>
    }

    fileprivate var routes: [RouteDefinition]
    let middlewares: MiddlewareGroup<Context>
}

@available(macOS 14, iOS 17, tvOS 17, *)
extension RouterMethods {
    /// Add route collection to router
    /// - Parameters
    ///   - collection: Route collection
    ///   - path: Root path to add routes to
    @discardableResult public func addRoutes(_ collection: RouteCollection<Context>, atPath path: RouterPath = "") -> Self {
        for route in collection.routes {
            // ensure path starts with a "/" and doesn't end with a "/"
            let path = path.appendingPath(route.path)
            self.on(path, method: route.method, responder: route.responder)
        }
        return self
    }
}
