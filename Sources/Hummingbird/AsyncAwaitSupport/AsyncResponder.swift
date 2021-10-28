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

#if compiler(>=5.5) && canImport(_Concurrency)

import NIO

/// Responder that calls supplied closure
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public struct HBAsyncCallbackResponder: HBResponder {
    let callback: @Sendable (HBRequest) async throws -> HBResponse

    public init(callback: @escaping @Sendable (HBRequest) async throws -> HBResponse) {
        self.callback = callback
    }

    /// Return EventLoopFuture that will be fulfilled with response to the request supplied
    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        let promise = request.eventLoop.makePromise(of: HBResponse.self)
        promise.completeWithTask {
            try await callback(request)
        }
        return promise.futureResult
    }
}

#endif
