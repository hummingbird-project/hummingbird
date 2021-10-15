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

import Logging
import NIOCore

class HBJobQueueWorker {
    let queue: HBJobQueue
    let eventLoop: EventLoop
    var promise: EventLoopPromise<Void>
    var isShutdown: Bool
    var logger: Logger

    init(queue: HBJobQueue, eventLoop: EventLoop, logger: Logger) {
        self.queue = queue
        self.eventLoop = eventLoop
        self.promise = self.eventLoop.makePromise()
        self.promise.succeed(())
        self.isShutdown = false
        self.logger = logger
    }

    func start() {
        self.executeNextJob()
    }

    func shutdown() -> EventLoopFuture<Void> {
        return self.eventLoop.flatSubmit {
            self.isShutdown = true
            return self.promise.futureResult
        }
    }

    /// execute next task on the queue. Once that task is complete this cal
    func executeNextJob() {
        self.eventLoop.execute {
            self.pop(on: self.eventLoop)
                .whenComplete { result in
                    self.promise = self.eventLoop.makePromise()
                    switch result {
                    case .success(let queuedJob):
                        self.executeJob(queuedJob, eventLoop: self.eventLoop, logger: self.logger)
                            .flatMap { _ in
                                self.queue.finished(jobId: queuedJob.id, on: self.eventLoop)
                            }
                            .whenComplete { _ in
                                self.promise.succeed(())
                                if self.isShutdown == false {
                                    self.executeNextJob()
                                }
                            }
                    case .failure(let error):
                        switch error {
                        case is HBJobQueueShutdownError:
                            break
                        default:
                            self.logger.error("Job queue error: \(error)")
                        }
                        self.promise.succeed(())
                        if self.isShutdown == false {
                            self.executeNextJob()
                        }
                    }
                }
        }
    }

    func pop(on eventLoop: EventLoop) -> EventLoopFuture<HBQueuedJob> {
        let promise = eventLoop.makePromise(of: HBQueuedJob.self)

        eventLoop.scheduleRepeatedAsyncTask(initialDelay: .zero, delay: self.queue.pollTime) { task in
            guard !self.isShutdown else {
                promise.fail(self.queue.shutdownError)
                task.cancel()
                return eventLoop.makeFailedFuture(self.queue.shutdownError)
            }
            return self.queue.pop(on: eventLoop)
                .map { value in
                    if let value = value {
                        promise.succeed(value)
                        task.cancel()
                    }
                }
                .flatMapErrorThrowing { error in
                    promise.fail(error)
                    task.cancel()
                    throw error
                }
        }
        return promise.futureResult
    }

    /// execute single job
    func executeJob(_ queuedJob: HBQueuedJob, eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        var logger = logger
        logger[metadataKey: "hb_job_id"] = .stringConvertible(queuedJob.id)
        logger[metadataKey: "hb_job_type"] = .string(String(describing: type(of: queuedJob.job.job)))

        logger.debug("Executing job")
        return self.executeJob(queuedJob, attemptNumber: 0, eventLoop: eventLoop, logger: logger).always { result in
            switch result {
            case .success:
                logger.debug("Completed job")
            case .failure:
                logger.error("Failed to complete job")
            }
        }
    }

    /// execute single job, retrying if it fails
    func executeJob(_ queuedJob: HBQueuedJob, attemptNumber: Int, eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        let job = queuedJob.job.job
        return job.execute(on: eventLoop, logger: logger)
            .flatMapError { error in
                guard attemptNumber < type(of: job).maxRetryCount else {
                    return job.onError(error, on: eventLoop, logger: logger)
                }
                logger.trace(
                    "Retrying job",
                    metadata: [
                        "hb_job_attempt": .stringConvertible(attemptNumber + 1),
                    ]
                )
                return self.executeJob(queuedJob, attemptNumber: attemptNumber + 1, eventLoop: eventLoop, logger: logger)
            }
    }
}
