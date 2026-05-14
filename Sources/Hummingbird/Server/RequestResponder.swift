//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import NIOCore
import ServiceContextModule

/// Protocol for object that produces a response given a request
///
/// This is the core protocol for Hummingbird. It defines an object that can respond to a request.
public protocol HTTPResponder<Context>: Sendable {
    associatedtype Context
    /// Return response to the request supplied
    @Sendable func respond(to request: Request, context: Context) async throws -> Response
}

/// Responder that calls supplied closure
public struct CallbackResponder<Context>: HTTPResponder {
    let callback: @Sendable (Request, Context) async throws -> Response

    public init(callback: @escaping @Sendable (Request, Context) async throws -> Response) {
        self.callback = callback
    }

    public func respond(to request: Request, context: Context) async throws -> Response {
        try await self.callback(request, context)
    }
}
