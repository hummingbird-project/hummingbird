//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

/// Middleware protocol with generic input, context and output types
public protocol MiddlewareProtocol<Input, Writer, Context>: Sendable {
    associatedtype Input
    associatedtype Writer: ~Copyable
    associatedtype Context

    func handle(
        _ input: Input,
        writer: consuming Writer,
        context: Context,
        next: (Input, consuming Writer, Context) async throws -> Void
    ) async throws
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
@available(hummingbird 3.0, *)
public protocol RouterMiddleware<Context>: MiddlewareProtocol where Input == Request, Writer == AnyResponseWriter {}

@available(hummingbird 3.0, *)
struct MiddlewareResponder<Context>: HTTPResponder {
    let middleware: any MiddlewareProtocol<Request, AnyResponseWriter, Context>
    let next: @Sendable (Request, consuming AnyResponseWriter, Context) async throws -> Void

    func respond(to request: Request, writer: consuming AnyResponseWriter, context: Context) async throws {
        try await self.middleware.handle(request, writer: writer, context: context) { request, writer, context in
            try await self.next(request, writer, context)
        }
    }
}
