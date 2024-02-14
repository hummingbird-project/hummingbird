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

import Collections
import Foundation

/// In memory implementation of job queue driver. Stores jobs in a circular buffer
public final class HBMemoryJobQueue: HBJobQueue {
    public typealias Element = HBQueuedJob

    /// queue of jobs
    fileprivate let queue: Internal
    private let onFailedJob: @Sendable (HBQueuedJob, any Error) -> Void

    /// Initialise In memory job queue
    public init(onFailedJob: @escaping @Sendable (HBQueuedJob, any Error) -> Void = { _, _ in }) {
        self.queue = .init()
        self.onFailedJob = onFailedJob
    }

    /// Shutdown queue
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
    @discardableResult public func push(_ job: HBJob) async throws -> JobIdentifier {
        try await self.queue.push(job)
    }

    public func finished(jobId: JobIdentifier) async throws {
        await self.queue.clearPendingJob(jobId: jobId)
    }

    public func failed(jobId: JobIdentifier, error: any Error) async throws {
        if let job = await self.queue.clearAndReturnPendingJob(jobId: jobId) {
            self.onFailedJob(.init(id: jobId, job: job), error)
        }
    }

    /// Internal actor managing the job queue
    fileprivate actor Internal {
        var queue: Deque<Data>
        var pendingJobs: [JobIdentifier: HBJob]
        var isStopped: Bool

        init() {
            self.queue = .init()
            self.isStopped = false
            self.pendingJobs = .init()
        }

        func push(_ job: HBJob) throws -> JobIdentifier {
            let queuedJob = HBQueuedJob(job)
            let jsonData = try JSONEncoder().encode(queuedJob)
            self.queue.append(jsonData)
            return queuedJob.id
        }

        func clearPendingJob(jobId: JobIdentifier) {
            self.pendingJobs[jobId] = nil
        }

        func clearAndReturnPendingJob(jobId: JobIdentifier) -> HBJob? {
            let instance = self.pendingJobs[jobId]
            self.pendingJobs[jobId] = nil
            return instance
        }

        func next() async throws -> HBQueuedJob? {
            while true {
                if self.isStopped {
                    return nil
                }
                if let data = queue.popFirst() {
                    do {
                        let job = try JSONDecoder().decode(HBQueuedJob.self, from: data)
                        self.pendingJobs[job.id] = job.job
                        return job
                    } catch {
                        throw JobQueueError.decodeJobFailed
                    }
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

extension HBMemoryJobQueue {
    public struct AsyncIterator: AsyncIteratorProtocol {
        fileprivate let queue: Internal

        public func next() async throws -> Element? {
            try await self.queue.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(queue: self.queue)
    }
}
