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

import Foundation
import Hummingbird
import Logging

/// Identifier for Job
public struct JobIdentifier: Sendable, CustomStringConvertible, Codable {
    let id: String

    init() {
        self.id = UUID().uuidString
    }

    /// Initialize JobIdentifier from String
    /// - Parameter value: string value
    public init(_ value: String) {
        self.id = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }

    /// String description of Identifier
    public var description: String { self.id }
}

/// Job queue protocol.
///
/// Defines how to push and pop jobs off a queue
public protocol HBJobQueue: AsyncSequence, Sendable {
    /// Push Job onto queue
    /// - Returns: Queued job information
    @discardableResult func push(_ job: HBJob) async throws -> JobIdentifier
    /// This is called to say job has finished processing and it can be deleted
    /// - Returns: When deletion of job has finished
    func finished(jobId: JobIdentifier) async
    /// shutdown queue
    func shutdown() async throws
    /// time amount between each poll of queue
    var pollTime: TimeAmount { get }
}

extension HBJobQueue {
    /// Default implememtatoin of `finish`. Does nothing
    /// - Parameters:
    ///   - jobId: Job Identifier
    /// - Returns: When deletion of job has finished. In this case immediately
    public func finished(jobId: JobIdentifier) async throws {}

    /// Default implementation of `shutdown`. Does nothing
    public func shutdown() async throws {}

    public var shutdownError: Error { return HBJobQueueShutdownError() }

    /// Queue workers poll the queue to get the latest jobs off the queue. This indicates the time amount
    /// between each poll of the queue
    public var pollTime: TimeAmount { .milliseconds(100) }
}

/// Error type for when a job queue is being shutdown
struct HBJobQueueShutdownError: Error {}
