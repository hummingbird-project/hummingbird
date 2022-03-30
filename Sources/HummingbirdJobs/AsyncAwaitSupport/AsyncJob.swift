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

import HummingbirdCore
#if compiler(>=5.6)
@preconcurrency import Logging
@preconcurrency import NIOCore
#else
import Logging
import NIOCore
#endif

/// Job with asynchronous handler
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public protocol HBAsyncJob: HBJob, HBSendable {
    /// Execute job
    func execute(logger: Logger) async throws
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBAsyncJob {
    func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        let promise = eventLoop.makePromise(of: Void.self)
        promise.completeWithTask {
            try await execute(logger: logger)
        }
        return promise.futureResult
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
