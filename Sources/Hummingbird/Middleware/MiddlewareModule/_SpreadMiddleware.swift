//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

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

public import HummingbirdCore

@_documentation(visibility: internal)
public struct _SpreadMiddleware<M0: MiddlewareProtocol>: MiddlewareProtocol where M0.Writer: ~Copyable {
    public typealias Input = M0.Input
    public typealias Writer = M0.Writer
    public typealias Context = M0.Context

    let middlewares: [M0]

    public func handle(
        _ input: Input,
        writer: consuming Writer,
        context: Context,
        next: (Input, consuming Writer, Context) async throws -> Void
    ) async throws {
        return try await handle(middlewares: self.middlewares, input: input, writer: writer, context: context, next: next)

        func handle(
            middlewares: some Collection<M0>,
            input: Input,
            writer: consuming Writer,
            context: Context,
            next: (Input, consuming Writer, Context) async throws -> Void
        ) async throws {
            guard let current = middlewares.first else {
                return try await next(input, writer, context)
            }

            return try await current.handle(
                input,
                writer: writer,
                context: context,
                next: { input, writer, context in
                    try await handle(middlewares: middlewares.dropFirst(), input: input, writer: writer, context: context, next: next)
                }
            )
        }
    }
}

@available(hummingbird 3.0, *)
extension _SpreadMiddleware: RouterMiddleware where M0.Input == Request, M0.Writer == AnyResponseWriter {}
