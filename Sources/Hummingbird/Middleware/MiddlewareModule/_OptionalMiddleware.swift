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
public struct _OptionalMiddleware<M0: MiddlewareProtocol>: MiddlewareProtocol {
    public typealias Input = M0.Input
    public typealias Output = M0.Output
    public typealias Context = M0.Context

    public let middleware: M0?

    @inlinable
    public func handle(_ input: M0.Input, context: M0.Context, next: (M0.Input, M0.Context) async throws -> M0.Output) async throws -> M0.Output {
        guard let middleware else {
            return try await next(input, context)
        }

        return try await middleware.handle(input, context: context, next: next)
    }
}

extension _OptionalMiddleware: RouterMiddleware where M0.Input == Request, M0.Output == Response {}
