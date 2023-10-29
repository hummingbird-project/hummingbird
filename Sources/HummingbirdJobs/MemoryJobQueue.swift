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

    public struct AsyncIterator: AsyncIteratorProtocol {
        fileprivate let queue: Internal

        public func next() async throws -> Element? {
            try await self.queue.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        .init(queue: self.queue)
    }

    /// Initialise In memory job queue
    public init() {
        self.queue = .init()
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
    public func push(_ job: HBJob) async throws -> JobIdentifier {
        try await self.queue.push(job)
    }

    public func finished(jobId: JobIdentifier) async throws {}

    public func failed(jobId: JobIdentifier) async throws {}

    /// Internal actor managing the job queue
    fileprivate actor Internal {
        var queue: Deque<Data>
        var isStopped: Bool

        init() {
            self.queue = .init()
            self.isStopped = false
        }

        func push(_ job: HBJob) throws -> JobIdentifier {
            let queuedJob = HBQueuedJob(job)
            let jsonData = try JSONEncoder().encode(queuedJob)
            self.queue.append(jsonData)
            return queuedJob.id
        }

        func next() async throws -> HBQueuedJob? {
            while true {
                if self.isStopped {
                    return nil
                }
                if let data = queue.popFirst() {
                    do {
                        let job = try JSONDecoder().decode(HBQueuedJob.self, from: data)
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
            self.isStopped = true
        }
    }
}

extension HBMemoryJobQueue {}
