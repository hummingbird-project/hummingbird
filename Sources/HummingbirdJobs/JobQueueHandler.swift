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

import AsyncAlgorithms
import Hummingbird
import Logging
import ServiceLifecycle

/// Object handling a single job queue
public final class HBJobQueueHandler<Queue: HBJobQueue>: Service {
    public init(queue: Queue, numWorkers: Int, logger: Logger) {
        self.queue = queue
        self.numWorkers = numWorkers
        self.logger = logger
    }

    public func run() async throws {
        try await self.queue.onInit()

        try await withGracefulShutdownHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var iterator = self.queue.makeAsyncIterator()
                for _ in 0..<self.numWorkers {
                    if let job = try await self.getNextJob(&iterator) {
                        group.addTask {
                            try await self.runJob(job)
                        }
                    }
                }
                while let job = try await self.getNextJob(&iterator) {
                    try await group.next()
                    group.addTask {
                        try await self.runJob(job)
                    }
                }
                group.cancelAll()
            }
            await self.queue.shutdownGracefully()
        } onGracefulShutdown: {
            Task {
                await self.queue.stop()
            }
        }
    }

    func getNextJob(_ queueIterator: inout Queue.AsyncIterator) async throws -> HBQueuedJob? {
        while true {
            do {
                let job = try await queueIterator.next()
                return job
            } catch let error as JobQueueError where error == JobQueueError.decodeJobFailed {
                self.logger.error("Job failed to decode.")
            }
        }
    }

    func runJob(_ queuedJob: HBQueuedJob) async throws {
        var logger = logger
        logger[metadataKey: "hb_job_id"] = .stringConvertible(queuedJob.id)
        logger[metadataKey: "hb_job_type"] = .string(String(describing: type(of: queuedJob.job.job)))

        let job = queuedJob.job
        var count = type(of: job.job).maxRetryCount
        logger.trace("Starting Job")
        while true {
            do {
                try await job.job.execute(logger: self.logger)
                break
            } catch let error as CancellationError {
                logger.error("Job cancelled")
                try await self.queue.failed(jobId: queuedJob.id, error: error)
                return
            } catch {
                if count == 0 {
                    logger.error("Job failed")
                    try await self.queue.failed(jobId: queuedJob.id, error: error)
                    return
                }
                count -= 1
                logger.debug("Retrying Job")
            }
        }
        logger.trace("Finished Job")
        try await self.queue.finished(jobId: queuedJob.id)
    }

    private let queue: Queue
    private let numWorkers: Int
    let logger: Logger
}
