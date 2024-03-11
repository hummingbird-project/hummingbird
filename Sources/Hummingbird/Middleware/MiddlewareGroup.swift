//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Group of middleware that can be used to create a responder chain. Each middleware calls the next one
public final class MiddlewareGroup<Context> {
    var middlewares: [any RouterMiddleware<Context>]

    /// Initialize `MiddlewareGroup`
    init(middlewares: [any RouterMiddleware<Context>] = []) {
        self.middlewares = middlewares
    }

    /// Add middleware to group
    public func add(_ middleware: any RouterMiddleware<Context>) {
        self.middlewares.append(middleware)
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
