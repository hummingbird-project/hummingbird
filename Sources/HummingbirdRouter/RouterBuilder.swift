//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird

/// Router Options
public struct RouterBuilderOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Router path comparisons will be case insensitive
    public static var caseInsensitive: Self { .init(rawValue: 1 << 0) }
}

/// Router built using a result builder
public struct RouterBuilder<Context: RouterRequestContext, Handler: MiddlewareProtocol>: MiddlewareProtocol where Handler.Input == Request, Handler.Output == Response, Handler.Context == Context {
    public typealias Input = Request
    public typealias Output = Response

    let handler: Handler
    let options: RouterBuilderOptions

    /// Initialize RouterBuilder with contents of result builder
    /// - Parameters:
    ///   - context: Request context used by router
    ///   - options: Router options
    ///   - builder: Result builder for router
    public init(
        context: Context.Type = Context.self,
        options: RouterBuilderOptions = [],
        @MiddlewareFixedTypeBuilder<Input, Output, Context> builder: () -> Handler
    ) {
        self.options = options
        self.handler = RouterBuilderState.$current.withValue(.init(options: options)) {
            builder()
        }
    }

    /// Process HTTP request and return an HTTP response
    /// - Parameters:
    ///   - input: HTTP Request
    ///   - context: Request context
    ///   - next: Next middleware to call if router doesn't hit a route
    /// - Returns: HTTP Response
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        var context = context
        var path = input.uri.path
        if self.options.contains(.caseInsensitive) {
            path = path.lowercased()
        }
        context.routerContext.remainingPathComponents = path.split(separator: "/")[...]
        return try await self.handler.handle(input, context: context, next: next)
    }
}

/// extend Router to conform to Responder so we can use it to process `Request``
extension RouterBuilder: HTTPResponder, HTTPResponderBuilder {
    public func respond(to request: Input, context: Context) async throws -> Output {
        do {
            return try await self.handle(request, context: context) { _, _ in
                throw HTTPError(.notFound)
            }
        } catch let error as HTTPResponseError {
            return try error.response(from: request, context: context)
        }
    }

    public func buildResponder() -> Self {
        return self
    }
}
