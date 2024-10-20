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

/// A middleware that can handle an array of middleware.
///
/// This middleware is useful for situations where you want to compose an array of middleware together.
///
/// You won't typically construct this middleware directly, but instead will use standard `for` loop
/// statements in a result builder to automatically build spread middleware:
///
/// ```swift
/// router.addMiddleware {
///   for logger in loggers {
///     LoggingMiddleware(logger: logger)
///   }
/// }
/// ```
@_documentation(visibility: internal)
public struct _SpreadMiddleware<M0: MiddlewareProtocol>: MiddlewareProtocol {
    public typealias Input = M0.Input
    public typealias Output = M0.Output
    public typealias Context = M0.Context

    let middlewares: [M0]

    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        return try await handle(middlewares: self.middlewares, input: input, context: context, next: next)

        func handle(middlewares: some Collection<M0>, input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
            guard let current = middlewares.first else {
                return try await next(input, context)
            }

            return try await current.handle(input, context: context, next: { input, context in
                try await handle(middlewares: middlewares.dropFirst(), input: input, context: context, next: next)
            })
        }
    }
}

extension _SpreadMiddleware: RouterMiddleware where M0.Input == Request, M0.Output == Response {}
