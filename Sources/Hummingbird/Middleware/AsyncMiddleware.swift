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

#if compiler(>=5.5) && $AsyncAwait
import _Concurrency

/// Middleware using async/await
@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
public protocol HBAsyncMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension HBAsyncMiddleware {
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        let promise = request.eventLoop.makePromise(of: HBResponse.self)
        promise.completeWithAsync {
            return try await apply(to: request, next: next)
        }
        return promise.futureResult
    }
}

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
extension HBResponder {
    /// extend HBResponder to provide async/await version of respond
    public func respond(to request: HBRequest) async throws -> HBResponse {
        return try await self.respond(to: request).get()
    }
}

#endif // compiler(>=5.5) && $AsyncAwait
