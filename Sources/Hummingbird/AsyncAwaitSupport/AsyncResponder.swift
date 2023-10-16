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

import NIO
import ServiceContextModule

/// Responder that calls supplied closure
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct HBAsyncCallbackResponder<Context: HBRequestContext>: HBResponder {
    let callback: @Sendable (HBRequest, Context) async throws -> HBResponse

    public init(callback: @escaping @Sendable (HBRequest, Context) async throws -> HBResponse) {
        self.callback = callback
    }

    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    public func respond(to request: HBRequest, context: Context) -> EventLoopFuture<HBResponse> {
        let promise = context.eventLoop.makePromise(of: HBResponse.self)
        return ServiceContext.$current.withValue(context.serviceContext) {
            promise.completeWithTask {
                try await self.callback(request, context)
            }
            return promise.futureResult
        }
    }
}
