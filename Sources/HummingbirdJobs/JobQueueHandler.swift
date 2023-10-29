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

    /// Push Job onto queue
    /// - Returns: Queued job information
    @discardableResult public func enqueue(_ job: HBJob) async throws -> JobIdentifier {
        try await self.queue.push(job)
    }

    public func run() async throws {
        try await withGracefulShutdownHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var iterator = self.queue.makeAsyncIterator()
                for _ in 0..<self.numWorkers {
                    if let job = try await iterator.next() {
                        try await self.runJob(job)
                    }
                }
                for try await job in self.queue {
                    group.addTask {
                        try await self.runJob(job)
                    }
                    try await group.next()
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
            } catch is CancellationError {
                logger.error("Job cancelled")
                return
            } catch {
                if count == 0 {
                    logger.error("Job failed")
                    try await self.queue.failed(jobId: queuedJob.id)
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
