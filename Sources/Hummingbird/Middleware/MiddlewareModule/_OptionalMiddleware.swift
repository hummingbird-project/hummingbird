//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// A middleware that can handle an optional middleware.
///
/// This middleware is useful for situations where you want to optionally unwrap a middleware.
///
/// You won't typically construct this middleware directly, but instead will use standard `if`-`else`
/// statements in a parser builder to automatically build conditional middleware:
///
/// ```swift
/// router.addMiddleware {
///   if let middleware {
///     middleware
///   }
///   ...
/// }
/// ```

public import HummingbirdCore

@_documentation(visibility: internal)
public struct _OptionalMiddleware<M0: MiddlewareProtocol>: MiddlewareProtocol where M0.Writer: ~Copyable {
    public typealias Input = M0.Input
    public typealias Writer = M0.Writer
    public typealias Context = M0.Context

    public let middleware: M0?

    @inlinable
    public func handle(
        _ input: M0.Input,
        writer: consuming Writer,
        context: M0.Context,
        next: (M0.Input, consuming M0.Writer, M0.Context) async throws -> Void
    ) async throws {
        guard let middleware else {
            return try await next(input, writer, context)
        }

        return try await middleware.handle(input, writer: writer, context: context, next: next)
    }
}

@available(hummingbird 3.0, *)
extension _OptionalMiddleware: RouterMiddleware where M0.Input == Request, M0.Writer == AnyResponseWriter {}
