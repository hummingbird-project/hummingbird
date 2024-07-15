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

/// Middleware protocol with generic input, context and output types
public protocol MiddlewareProtocol<Input, Output, Context>: Sendable {
    associatedtype Input
    associatedtype Output
    associatedtype Context

    func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output
}

/// Applied to `Request` before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// (either the next middleware or a route) by calling `next(request, context)`. If you want to shortcut the request you
/// can return a response immediately
///
/// Middleware is added to the application by calling `router.middlewares.add(MyMiddleware()`.
///
/// Middleware allows you to process a request before it reaches your request handler and then process the response
/// returned by that handler.
/// ```
/// func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response
///     let request = processRequest(request)
///     let response = try await next(request, context)
///     return processResponse(response)
/// }
/// ```
/// Middleware also allows you to shortcut the whole process and not pass on the request to the handler
/// ```
/// func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response
///     if request.method == .OPTIONS {
///         return Response(status: .noContent)
///     } else {
///         return try await next(request, context)
///     }
/// }
/// ```

/// Middleware protocol with Request as input and Response as output
public protocol RouterMiddleware<Context>: MiddlewareProtocol where Input == Request, Output == Response {}

struct MiddlewareResponder<Context>: HTTPResponder {
    let middleware: any MiddlewareProtocol<Request, Response, Context>
    let next: @Sendable (Request, Context) async throws -> Response

    func respond(to request: Request, context: Context) async throws -> Response {
        return try await self.middleware.handle(request, context: context) { request, context in
            try await self.next(request, context)
        }
    }
}
