//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Group of middleware that can be used to create a responder chain. Each middleware calls the next one
public final class MiddlewareGroup<Context> {
    var middlewares: [any MiddlewareProtocol<Request, Response, Context>]

    /// Initialize `MiddlewareGroup`
    init(middlewares: [any MiddlewareProtocol<Request, Response, Context>] = []) {
        self.middlewares = middlewares
    }

    /// Add middleware to group
    ///
    /// This middleware will only be applied to endpoints added after this call.
    @discardableResult public func add(_ middleware: any MiddlewareProtocol<Request, Response, Context>) -> Self {
        self.middlewares.append(middleware)
        return self
    }

    /// Construct responder chain from this middleware group
    /// - Parameter finalResponder: The responder the last middleware calls
    /// - Returns: Responder chain
    public func constructResponder(finalResponder: any HTTPResponder<Context>) -> any HTTPResponder<Context> {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser.respond(to:context:))
            currentResponser = responder
        }
        return currentResponser
    }
}
