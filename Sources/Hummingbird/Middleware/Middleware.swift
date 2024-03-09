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

import NIOCore

/// Middleware Handler with generic input, context and output types
public typealias Middleware<Input, Output, Context> = @Sendable (Input, Context, _ next: (Input, Context) async throws -> Output) async throws -> Output

/// Middleware protocol with generic input, context and output types
public protocol MiddlewareProtocol<Input, Output, Context>: Sendable {
    associatedtype Input
    associatedtype Output
    associatedtype Context

    func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output
}

/// Applied to `HBRequest` before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// (either the next middleware or a route) by calling `next(request, context)`. If you want to shortcut the request you
/// can return a response immediately
///
/// Middleware is added to the application by calling `router.middlewares.add(MyMiddleware()`.
///
/// Middleware allows you to process a request before it reaches your request handler and then process the response
/// returned by that handler.
/// ```
/// func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse
///     let request = processRequest(request)
///     let response = try await next(request, context)
///     return processResponse(response)
/// }
/// ```
/// Middleware also allows you to shortcut the whole process and not pass on the request to the handler
/// ```
/// func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse
///     if request.method == .OPTIONS {
///         return HBResponse(status: .noContent)
///     } else {
///         return try await next(request, context)
///     }
/// }
/// ```

/// Middleware protocol with HBRequest as input and HBResponse as output
public protocol HBMiddlewareProtocol<Context>: MiddlewareProtocol where Input == HBRequest, Output == HBResponse {}

struct MiddlewareResponder<Context>: HBRequestResponder {
    let middleware: any HBMiddlewareProtocol<Context>
    let next: @Sendable (HBRequest, Context) async throws -> HBResponse

    func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        return try await self.middleware.handle(request, context: context) { request, context in
            try await self.next(request, context)
        }
    }
}
