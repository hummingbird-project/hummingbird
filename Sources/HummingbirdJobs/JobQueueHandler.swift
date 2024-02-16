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
                            await self.runJob(job)
                        }
                    }
                }
                while let job = try await self.getNextJob(&iterator) {
                    try await group.next()
                    group.addTask {
                        await self.runJob(job)
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

    func getNextJob(_ queueIterator: inout Queue.AsyncIterator) async throws -> HBQueuedJob<Queue.JobID>? {
        while true {
            do {
                let job = try await queueIterator.next()
                return job
            } catch let error as JobQueueError where error == JobQueueError.decodeJobFailed {
                self.logger.error("Job failed to decode.")
            }
        }
    }

    func runJob(_ queuedJob: HBQueuedJob<Queue.JobID>) async {
        var logger = logger
        logger[metadataKey: "hb_job_id"] = .stringConvertible(queuedJob.id)
        logger[metadataKey: "hb_job_type"] = .string(String(describing: type(of: queuedJob.job)))

        let job = queuedJob.job
        var count = type(of: job).maxRetryCount
        logger.debug("Starting Job")

        do {
            while true {
                do {
                    try await job.execute(logger: self.logger)
                    break
                } catch let error as CancellationError {
                    logger.debug("Job cancelled")
                    // Job failed is called but due to the fact the task is cancelled, depending on the
                    // job queue driver, the process of failing the job might not occur because itself
                    // might get cancelled
                    try await self.queue.failed(jobId: queuedJob.id, error: error)
                    return
                } catch {
                    if count == 0 {
                        logger.debug("Job failed")
                        try await self.queue.failed(jobId: queuedJob.id, error: error)
                        return
                    }
                    count -= 1
                    logger.debug("Retrying Job")
                }
            }
            logger.debug("Finished Job")
            try await self.queue.finished(jobId: queuedJob.id)
        } catch {
            logger.debug("Failed to set job status")
        }
    }

    private let queue: Queue
    private let numWorkers: Int
    let logger: Logger
}

extension HBJobQueueHandler: CustomStringConvertible {
    public var description: String { "HBJobQueueHandler<\(String(describing: Queue.self))>" }
}
