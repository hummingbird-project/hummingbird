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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import NIOCore

/// Job with asynchronous handler
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBJobQueue {
    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job descriptor
    ///   - maxRetryCount: Number of times you should retry job
    /// - Returns: ID for job
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) async throws -> JobIdentifier {
        return try await self.push(job, on: eventLoop).map(\.id).get()
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
