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

import Hummingbird
import Logging

/// Object handling a single job queue
public class HBJobQueueHandler {
    public init(queue: HBJobQueue, numWorkers: Int, eventLoopGroup: EventLoopGroup, logger: Logger) {
        self.queue = queue
        self.workers = (0..<numWorkers).map { _ in
            HBJobQueueWorker(queue: queue, eventLoop: eventLoopGroup.next(), logger: logger)
        }
        self.eventLoop = eventLoopGroup.next()
    }

    /// Push Job onto queue
    /// - Returns: Queued job information
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) -> EventLoopFuture<JobIdentifier> {
        self.queue.enqueue(job, on: eventLoop)
    }

    /// Start queue workers
    public func start() {
        self.queue.onInit(on: self.eventLoop).whenComplete { _ in
            self.workers.forEach {
                $0.start()
            }
        }
    }

    /// Shutdown queue workers and queue
    public func shutdown() -> EventLoopFuture<Void> {
        // shutdown all workers
        let shutdownFutures: [EventLoopFuture<Void>] = self.workers.map { $0.shutdown() }
        return EventLoopFuture.andAllComplete(shutdownFutures, on: self.eventLoop).flatMap { _ in
            self.queue.shutdown(on: self.eventLoop)
        }
    }

    private let eventLoop: EventLoop
    fileprivate let queue: HBJobQueue
    private let workers: [HBJobQueueWorker]
}

/// Job queue id
///
/// If you want to add a new task queue. Extend this class to include a new id
/// ```
/// extension HBJobQueueId {
///     public static var `myQueue`: HBJobQueueId { "myQueue" }
/// }
/// ```
/// and register new queue with tasks handler
/// ```
/// app.jobs.registerQueue(.myQueue, queue: .memory)
/// ```
/// If you don't register the queue your application will crash as soon as you try to use it
public struct HBJobQueueId: Hashable, ExpressibleByStringLiteral {
    public let id: String

    public init(stringLiteral: String) {
        self.id = stringLiteral
    }

    public init(_ string: String) {
        self.id = string
    }

    public static var `default`: HBJobQueueId { "_hb_default_" }
}

extension HBApplication {
    /// Object internal to `HBApplication` that handles its array of JobQueues.
    public class JobQueueHandler {
        /// Job queue id
        public typealias QueueKey = HBJobQueueId
        /// The default JobQueue setup at initialisation
        public var queue: HBJobQueue { self.queues[.default]!.queue }

        init(queue: HBJobQueueFactory, application: HBApplication, numWorkers: Int) {
            self.application = application
            self.queues = [:]
            self.registerQueue(.default, queue: queue, numWorkers: numWorkers)
        }

        /// Return queue given a job queue id.
        ///
        /// It is assumed the job queue has been setup and if the queue doesn't
        /// exist will crash the application
        /// - Parameter id: Job queue id
        /// - Returns: Job queue
        public func queues(_ id: QueueKey) -> HBJobQueue {
            return self.queues[id]!.queue
        }

        /// Register a job queue under an id
        ///
        /// - Parameters:
        ///   - id: Job queue id
        ///   - queueFactory: Job queue factory
        ///   - numWorkers: Number of workers you want servicing this job queue
        public func registerQueue(_ id: QueueKey, queue queueFactory: HBJobQueueFactory, numWorkers: Int) {
            let queue = queueFactory.create(self.application)
            let handler = HBJobQueueHandler(
                queue: queue,
                numWorkers: numWorkers,
                eventLoopGroup: application.eventLoopGroup,
                logger: self.logger
            )
            self.queues[id] = handler
        }

        func start() {
            for queue in self.queues {
                queue.value.start()
            }
        }

        func shutdown() -> EventLoopFuture<Void> {
            let eventLoop = self.application.eventLoopGroup.next()
            // shutdown all queues
            let shutdownFutures: [EventLoopFuture<Void>] = self.queues.values.map { $0.shutdown() }
            return EventLoopFuture.andAllComplete(shutdownFutures, on: eventLoop)
        }

        private let application: HBApplication
        private var logger: Logger { self.application.logger }
        private var queues: [QueueKey: HBJobQueueHandler]
    }

    /// Job queue handler
    public var jobs: JobQueueHandler { self.extensions.get(\.jobs) }

    /// Initialisation for Job queue system
    /// - Parameters:
    ///   - using: Default job queue driver
    ///   - numWorkers: Number of workers that will service the default queue
    public func addJobs(using: HBJobQueueFactory, numWorkers: Int) {
        self.extensions.set(\.jobs, value: .init(queue: using, application: self, numWorkers: numWorkers))
        self.lifecycle.register(
            label: "Jobs",
            start: .sync { self.jobs.start() },
            shutdown: .eventLoopFuture { self.jobs.shutdown() }
        )
    }
}
