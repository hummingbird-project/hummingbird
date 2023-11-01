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
/// Defines how to push and pop jobs off a queue
public protocol HBJobQueue: AsyncSequence, Sendable where Element == HBQueuedJob {
    /// Push Job onto queue
    /// - Returns: Queued job information
    @discardableResult func push(_ job: HBJob) async throws -> JobIdentifier
    /// This is called to say job has finished processing and it can be deleted
    func finished(jobId: JobIdentifier) async throws
    /// This is called to say job has failed to run and should be put aside
    func failed(jobId: JobIdentifier, error: any Error) async throws
    /// stop serving jobs
    func stop() async
    /// shutdown queue
    func shutdownGracefully() async
}
