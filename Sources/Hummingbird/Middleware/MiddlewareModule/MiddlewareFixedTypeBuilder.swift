//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) YEARS the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
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

/// Middleware stack result builder
///
/// Generates a middleware stack from the elements inside the result builder. The input,
/// context and output types passed through the middleware stack are fixed and cannot be changed.
@resultBuilder
public enum MiddlewareFixedTypeBuilder<Input, Output, Context> {
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

    public static func buildOptional<M0: MiddlewareProtocol>(_ component: M0?) -> _OptionalMiddleware<M0> {
        _OptionalMiddleware(middleware: component)
    }

    public static func buildEither<M0: MiddlewareProtocol>(
        first content: M0
    ) -> M0 {
        content
    }

    public static func buildEither<M0: MiddlewareProtocol>(
        second content: M0
    ) -> M0 {
        content
    }

    public static func buildArray<M0: MiddlewareProtocol>(_ components: [M0]) -> _SpreadMiddleware<M0> {
        return _SpreadMiddleware(middlewares: components)
    }
}
