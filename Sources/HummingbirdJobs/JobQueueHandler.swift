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

    public static var `default`: HBJobQueueId { "default" }
}

extension HBApplication {
    /// Handles the array of JobQueues.
    public class JobQueueHandler {
        /// Job queue id
        public typealias QueueKey = HBJobQueueId
        /// The default JobQueue setup at initialisation
        public var queue: HBJobQueue { self.queues[.default]! }

        init(queue: HBJobQueueFactory, application: HBApplication, numWorkers: Int) {
            self.application = application
            self.queues = [:]
            self.workers = []
            self.registerQueue(.default, queue: queue, numWorkers: numWorkers)
        }

        /// Return queue given a job queue id.
        ///
        /// It is assumed the job queue has been setup and if the queue doesn't
        /// exist will crash the application
        /// - Parameter id: Job queue id
        /// - Returns: Job queue
        public func queues(_ id: QueueKey) -> HBJobQueue {
            return self.queues[id]!
        }

        /// Register a job queue under an id
        ///
        /// - Parameters:
        ///   - id: Job queue id
        ///   - queueFactory: Job queue factory
        ///   - numWorkers: Number of workers you want servicing this job queue
        public func registerQueue(_ id: QueueKey, queue queueFactory: HBJobQueueFactory, numWorkers: Int) {
            let queue = queueFactory.create(self.application)
            self.queues[id] = queue
            for _ in 0..<numWorkers {
                let worker = HBJobQueueWorker(queue: queue, eventLoop: application.eventLoopGroup.next(), logger: self.logger)
                self.workers.append(worker)
            }
        }

        func start() {
            let eventLoop = self.application.eventLoopGroup.next()
            let initFutures = self.queues.values.map { $0.onInit(on: eventLoop) }
            EventLoopFuture.andAllComplete(initFutures, on: eventLoop).whenComplete { _ in
                self.workers.forEach {
                    $0.start()
                }
            }
        }

        func shutdown() -> EventLoopFuture<Void> {
            let eventLoop = self.application.eventLoopGroup.next()
            // shutdown all workers
            let shutdownFutures: [EventLoopFuture<Void>] = self.workers.map { $0.shutdown() }
            return EventLoopFuture.andAllComplete(shutdownFutures, on: eventLoop).flatMap {
                // shutdown all queues
                let shutdownFutures: [EventLoopFuture<Void>] = self.queues.values.map { $0.shutdown(on: eventLoop) }
                return EventLoopFuture.andAllComplete(shutdownFutures, on: eventLoop)
            }
        }

        private let application: HBApplication
        private var logger: Logger { self.application.logger }
        private var queues: [QueueKey: HBJobQueue]
        private var workers: [HBJobQueueWorker]
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
