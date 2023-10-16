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

/// Middleware using async/await
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol HBAsyncMiddleware: HBMiddleware {
    func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBAsyncMiddleware {
    public func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) -> EventLoopFuture<HBResponse> {
        let promise = context.eventLoop.makePromise(of: HBResponse.self)
        promise.completeWithTask {
            return try await ServiceContext.$current.withValue(context.serviceContext) {
                return try await self.apply(to: request, context: context, next: HBPropagateServiceContextResponder(responder: next, context: context))
            }
        }
        return promise.futureResult
    }
}

/// Propagate Task Local serviceContext back to HBRequest after running AsyncMiddleware
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct HBPropagateServiceContextResponder<Context: HBRequestContext>: HBResponder {
    let responder: any HBResponder<Context>
    let context: Context

    func respond(to request: HBRequest, context: Context) -> EventLoopFuture<HBResponse> {
        if let serviceContext = ServiceContext.$current.get() {
            return context.withServiceContext(serviceContext) { context in
                self.responder.respond(to: request, context: context)
            }
        } else {
            return self.responder.respond(to: request, context: context)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBResponder {
    /// extend HBResponder to provide async/await version of respond
    public func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        return try await self.respond(to: request, context: context).get()
    }
}
