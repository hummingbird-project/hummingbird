//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Collections
import Foundation

/// In memory implementation of job queue driver. Stores job data in a circular buffer
public final class HBMemoryQueue: HBJobQueueDriver {
    public typealias Element = HBQueuedJob<JobID>
    public typealias JobID = UUID

    /// queue of jobs
    fileprivate let queue: Internal
    private let onFailedJob: @Sendable (HBQueuedJob<JobID>, any Error) -> Void

    /// Initialise In memory job queue
    public init(onFailedJob: @escaping @Sendable (HBQueuedJob<JobID>, any Error) -> Void = { _, _ in }) {
        self.queue = .init()
        self.onFailedJob = onFailedJob
    }

    /// Stop queue serving more jobs
    public func stop() async {
        await self.queue.stop()
    }

    /// Shutdown queue
    public func shutdownGracefully() async {
        await self.queue.shutdown()
    }

    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job
    ///   - eventLoop: Eventloop to run process on (ignored in this case)
    /// - Returns: Queued job
    @discardableResult public func push(data: Data) async throws -> JobID {
        return try await self.queue.push(data)
    }

    public func finished(jobId: JobID) async throws {
        await self.queue.clearPendingJob(jobId: jobId)
    }

    public func failed(jobId: JobID, error: any Error) async throws {
        if let job = await self.queue.clearAndReturnPendingJob(jobId: jobId) {
            self.onFailedJob(.init(id: jobId, jobData: job), error)
        }
    }

    /// Internal actor managing the job queue
    fileprivate actor Internal {
        var queue: Deque<HBQueuedJob<JobID>>
        var pendingJobs: [JobID: Data]
        var isStopped: Bool

        init() {
            self.queue = .init()
            self.isStopped = false
            self.pendingJobs = .init()
        }

        func push(_ jobData: Data) throws -> JobID {
            let id = JobID()
            self.queue.append(HBQueuedJob(id: id, jobData: jobData))
            return id
        }

        func clearPendingJob(jobId: JobID) {
            self.pendingJobs[jobId] = nil
        }

        func clearAndReturnPendingJob(jobId: JobID) -> Data? {
            let instance = self.pendingJobs[jobId]
            self.pendingJobs[jobId] = nil
            return instance
        }

        func next() async throws -> HBQueuedJob<JobID>? {
            while true {
                if self.isStopped {
                    return nil
                }
                if let request = queue.popFirst() {
                    self.pendingJobs[request.id] = request.jobData
                    return request
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        func stop() {
            self.isStopped = true
        }

        func shutdown() {
            assert(self.pendingJobs.count == 0)
            self.isStopped = true
        }
    }
}

extension HBMemoryQueue {
    public struct AsyncIterator: AsyncIteratorProtocol {
        fileprivate let queue: Internal

        public mutating func next() async throws -> Element? {
            try await self.queue.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(queue: self.queue)
    }
}

extension HBJobQueueDriver where Self == HBMemoryQueue {
    /// Return In memory driver for Job Queue
    /// - Parameters:
    ///   - onFailedJob: Closure called when a job fails
    public static var memory: HBMemoryQueue {
        .init()
    }
}
