//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-middleware open source project
//
// Copyright (c) 2023 Apple Inc. and the swift-middleware project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of swift-middleware project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public func MiddlewareStack<Input, Output, Context, M0: MiddlewareProtocol>(
    input: Input.Type = Input.self,
    output: Output.Type = Output.self,
    context: Context.Type = Context.self,
    @MiddlewareBuilder<Input, Output, Context> _ builder: () -> M0
) -> M0 where M0.Input == Input, M0.Output == Output, M0.Context == Context {
    builder()
}

public struct MiddlewareClosure<Input, Output, Context>: MiddlewareProtocol {
    @usableFromInline
    var closure: Middleware<Input, Output, Context>

    @inlinable
    public init(_ middleware: @escaping Middleware<Input, Output, Context>) {
        self.closure = middleware
    }

    @inlinable
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        try await self.closure(input, context, next)
    }
}

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

@resultBuilder
public struct MiddlewareBuilder<Input, Output, Context> {
    public static func buildExpression<M0: MiddlewareProtocol>(_ m0: M0) -> M0 where M0.Input == Input, M0.Output == Output, M0.Context == Context {
        return m0
    }

    public static func buildBlock<M0: MiddlewareProtocol>(_ m0: M0) -> M0 {
        return m0
    }

    public static func buildPartialBlock<M0: MiddlewareProtocol>(first: M0) -> M0 {
        first
    }

    public static func buildPartialBlock<M0: MiddlewareProtocol, M1: MiddlewareProtocol>(
        accumulated m0: M0,
        next m1: M1
    ) -> _Middleware2<M0, M1> where M0.Input == M1.Input, M0.Output == M1.Output, M0.Context == M1.Context {
        _Middleware2(m0, m1)
    }
}
