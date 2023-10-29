//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

/// Applied to `HBRequest` before it is dealt with by the router. Middleware passes the processed request onto the next responder
/// (either the next middleware or the router) by calling `next.apply(to: request)`. If you want to shortcut the request you
/// can return a response immediately
///
/// Middleware is added to the application by calling `app.middleware.add(MyMiddleware()`.
///
/// Middleware allows you to process a request before it reaches your request handler and then process the response
/// returned by that handler.
/// ```
/// func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
///     let request = processRequest(request)
///     let response = try await next.respond(to: request)
///     return processResponse(response)
/// }
/// ```
/// Middleware also allows you to shortcut the whole process and not pass on the request to the handler
/// ```
/// func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
///     if request.method == .OPTIONS {
///         return HBResponse(status: .noContent)
///     } else {
///         return try await next.respond(to: request)
///     }
/// }
/// ```
public protocol HBMiddleware<Context>: Sendable {
    associatedtype Context: HBRequestContext
    func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) -> EventLoopFuture<HBResponse>
}

struct MiddlewareResponder<Context: HBRequestContext>: HBResponder {
    let middleware: any HBMiddleware<Context>
    let next: any HBResponder<Context>

    func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        return try await self.middleware.apply(to: request, context: context, next: self.next).get()
    }
}
