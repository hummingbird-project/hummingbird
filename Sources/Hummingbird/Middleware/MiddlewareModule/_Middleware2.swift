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

/// A middleware that composes two other middlewares.
///
/// The two provided middlewares will be chained together, with `M0` first executing, followed by `M1`.
///
/// You won't typically construct this middleware directly, but instead will use result builder syntax.
///
/// ```swift
/// router.addMiddleware {
///    MiddlewareOne()
///    MiddlewareTwo()
/// }
/// ```
public struct _Middleware2<M0: MiddlewareProtocol, M1: MiddlewareProtocol>: MiddlewareProtocol where M0.Input == M1.Input, M0.Context == M1.Context, M0.Output == M1.Output {
    public typealias Input = M0.Input
    public typealias Output = M0.Output
    public typealias Context = M0.Context

    @usableFromInline let m0: M0
    @usableFromInline let m1: M1

    @inlinable
    public init(_ m0: M0, _ m1: M1) {
        self.m0 = m0
        self.m1 = m1
    }

    @inlinable
    public func handle(_ input: M0.Input, context: M0.Context, next: (M0.Input, M0.Context) async throws -> M0.Output) async throws -> M0.Output {
        try await self.m0.handle(input, context: context) { input, context in
            try await self.m1.handle(input, context: context, next: next)
        }
    }
}

extension _Middleware2: RouterMiddleware where M0.Input == Request, M0.Output == Response {}
