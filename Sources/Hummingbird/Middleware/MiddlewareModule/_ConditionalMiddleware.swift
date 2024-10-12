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

/// A middleware that can handle two possible types of middleware.
///
/// This middleware is useful for situations where you want to run one of two different middlewares based on
/// a condition.
///
/// You won't typically construct this middleware directly, but instead will use standard `if`-`else`
/// statements in a parser builder to automatically build conditional middleware:
///
/// ```swift
/// router.addMiddleware {
///   if isRelease {
///     ReleaseMiddleware()
///   } else {
///     DebugMiddleware()
///   }
/// }
/// ```
public enum _ConditionalMiddleware<M0: MiddlewareProtocol, M1: MiddlewareProtocol>: MiddlewareProtocol where M0.Input == M1.Input, M0.Context == M1.Context, M0.Output == M1.Output {
    public typealias Input = M0.Input
    public typealias Output = M0.Output
    public typealias Context = M0.Context

    case first(M0)
    case second(M1)

    @inlinable
    public func handle(_ input: M0.Input, context: M0.Context, next: (M0.Input, M0.Context) async throws -> M0.Output) async throws -> M0.Output {
        switch self {
        case .first(let first):
            try await first.handle(input, context: context, next: next)
        case .second(let second):
            try await second.handle(input, context: context, next: next)
        }
    }
}

extension _ConditionalMiddleware: RouterMiddleware where M0.Input == Request, M0.Output == Response {}
