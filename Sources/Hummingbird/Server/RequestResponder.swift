//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore
import ServiceContextModule

/// Protocol for object that produces a response given a request
///
/// This is the core protocol for Hummingbird. It defines an object that can respond to a request.
@available(hummingbird 3.0, *)
public protocol HTTPResponder<Context>: Sendable {
    associatedtype Context
    /// Return response to the request supplied
    func respond(to request: Request, writer: consuming AnyResponseWriter, context: Context) async throws
}

/// Responder that calls supplied closure
@available(hummingbird 3.0, *)
public struct CallbackResponder<Context>: HTTPResponder<Context> {
    let callback: @Sendable (Request, consuming AnyResponseWriter, Context) async throws -> Void

    public init(callback: @escaping @Sendable (Request, consuming AnyResponseWriter, Context) async throws -> Void) {
        self.callback = callback
    }

    public func respond(to request: Request, writer: consuming AnyResponseWriter, context: Context) async throws {
        try await self.callback(request, writer, context)
    }
}
