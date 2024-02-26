//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Hummingbird
import Logging

/// Job queue protocol.
///
/// Defines how to push and pop job data off a queue
public protocol HBJobQueueDriver: AsyncSequence, Sendable where Element == HBQueuedJob<JobID> {
    associatedtype JobID: CustomStringConvertible & Sendable

    /// Called when JobQueueHandler is initialised with this queue
    func onInit() async throws
    /// Push Job onto queue
    /// - Returns: Identifier of queued job
    func push(data: Data) async throws -> JobID
    /// This is called to say job has finished processing and it can be deleted
    func finished(jobId: JobID) async throws
    /// This is called to say job has failed to run and should be put aside
    func failed(jobId: JobID, error: any Error) async throws
    /// stop serving jobs
    func stop() async
    /// shutdown queue
    func shutdownGracefully() async
}

extension HBJobQueueDriver {
    // default version of onInit doing nothing
    public func onInit() async throws {}
}
