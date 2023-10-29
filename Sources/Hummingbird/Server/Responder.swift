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
import ServiceContextModule

/// Protocol for object that produces a response given a request
///
/// This is the core protocol for Hummingbird. It defines an object that can respond to a request.
public protocol HBResponder<Context>: Sendable {
    associatedtype Context: HBRequestContext
    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    func respond(to request: HBRequest, context: Context) async throws -> HBResponse
}

/// Responder that calls supplied closure
public struct HBCallbackResponder<Context: HBRequestContext>: HBResponder {
    let callback: @Sendable (HBRequest, Context ) async throws -> HBResponse

    public init(callback: @escaping @Sendable (HBRequest, Context) async throws -> HBResponse) {
        self.callback = callback
    }

    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    public func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        return try await ServiceContext.$current.withValue(context.serviceContext) {
            try await self.callback(request, context)
        }
    }
}
