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

import Foundation
import NIOCore

/// In memory implementation of job queue driver. Stores jobs in a circular buffer
public class HBMemoryJobQueue: HBJobQueue {
    public let eventLoop: EventLoop

    /// queue of jobs
    var queue: CircularBuffer<Data>
    /// queue of workers waiting for a new job
    var waitingQueue: CircularBuffer<EventLoopPromise<Void>>

    /// Initialise In memory job queue
    /// - Parameter eventLoopGroup: EventLoop to run access to queue
    public init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.queue = .init(initialCapacity: 16)
        self.waitingQueue = .init(initialCapacity: 4)
    }

    /// Shutdown queue
    public func shutdown() -> EventLoopFuture<Void> {
        self.eventLoop.submit {
            self.waitingQueue.forEach {
                $0.fail(self.shutdownError)
            }
        }
    }

    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job
    ///   - eventLoop: Eventloop to run process on (ignored in this case)
    /// - Returns: Queued job
    public func push(_ job: HBJob, on eventLoop: EventLoop) -> EventLoopFuture<HBQueuedJob> {
        return self.eventLoop.submit { () -> HBQueuedJob in
            let queuedJob = HBQueuedJob(job)
            let jsonData = try JSONEncoder().encode(queuedJob)
            self.queue.append(jsonData)
            if let waiting = self.waitingQueue.popFirst() {
                waiting.succeed(())
            }
            return queuedJob
        }
    }

    /// Pop job off queue
    /// - Parameter eventLoop: Eventloop to run process on (ignored in this case)
    /// - Returns: Queued Job if available
    public func pop(on eventLoop: EventLoop) -> EventLoopFuture<HBQueuedJob?> {
        self.eventLoop.flatSubmit {
            if self.waitingQueue.count > 0 || self.queue.count == 0 {
                let promise = self.eventLoop.makePromise(of: Void.self)
                self.waitingQueue.append(promise)
                return promise.futureResult.flatMapThrowing { _ in
                    let jsonData = self.queue.popFirst()!
                    return try JSONDecoder().decode(HBQueuedJob.self, from: jsonData)
                }
            } else {
                let jsonData = self.queue.popFirst()!
                do {
                    let value = try JSONDecoder().decode(HBQueuedJob.self, from: jsonData)
                    return self.eventLoop.makeSucceededFuture(value)
                } catch {
                    return self.eventLoop.makeFailedFuture(error)
                }
            }
        }
    }
}
