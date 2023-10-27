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
public final class HBJobQueueHandler: Service {
    public init(queue: HBJobQueue, numWorkers: Int, logger: Logger) {
        self.queue = queue
        self.numWorkers = numWorkers
    }

    /// Push Job onto queue
    /// - Returns: Queued job information
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) async throws -> JobIdentifier {
        try await self.queue.push(job)
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

    private let queue: HBJobQueue
    private let numWorkers: Int
}

/// Job queue handler asynchronous enqueue
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBJobQueueHandler {
    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job descriptor
    ///   - maxRetryCount: Number of times you should retry job
    /// - Returns: ID for job
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) async throws -> JobIdentifier {
        try await self.enqueue(job, on: eventLoop).get()
    }

    /// Shutdown queue workers and queue
    public func shutdown() async throws {
        try await self.shutdown().get()
    }
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
public struct HBJobQueueId: Hashable, ExpressibleByStringLiteral, Sendable {
    public let id: String

    public init(stringLiteral: String) {
        self.id = stringLiteral
    }

    public init(_ string: String) {
        self.id = string
    }

    public static var `default`: HBJobQueueId { "_hb_default_" }
}
