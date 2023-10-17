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

extension HBResponder {
    /// extend HBResponder to provide async/await version of respond
    public func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        return try await self.respond(to: request, context: context).get()
    }
}

/// Responder that calls supplied closure
public struct HBAsyncCallbackResponder<Context: HBRequestContext>: HBResponder {
    let callback: @Sendable (HBRequest, Context) async throws -> HBResponse

    public init(callback: @escaping @Sendable (HBRequest, Context) async throws -> HBResponse) {
        self.callback = callback
    }
}

public extension HBAsyncCallbackResponder where Context: HBRequestContext {
    func respond(to request: HBRequest, context: Context) -> EventLoopFuture<HBResponse> {
        let promise = context.eventLoop.makePromise(of: HBResponse.self)
        promise.completeWithTask {
            return try await ServiceContext.$current.withValue(context.serviceContext) {
                try await self.callback(request, context)
            }
        }
        return promise.futureResult
    }
}
