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

import NIOCore

public class HBMemoryJobQueue: HBJobQueue {
    public let eventLoop: EventLoop

    var queue: CircularBuffer<HBQueuedJob>
    var waitingQueue: CircularBuffer<EventLoopPromise<Void>>

    public init(eventLoopGroup: EventLoopGroup) {
        self.eventLoop = eventLoopGroup.next()
        self.queue = .init(initialCapacity: 16)
        self.waitingQueue = .init(initialCapacity: 4)
    }

    public func shutdown() {
        self.waitingQueue.forEach {
            $0.fail(self.shutdownError)
        }
    }

    public func push(_ job: HBJob, on eventLoop: EventLoop) -> EventLoopFuture<HBQueuedJob> {
        return self.eventLoop.submit { () -> HBQueuedJob in
            let queuedJob = HBQueuedJob(job)
            self.queue.append(queuedJob)
            if let waiting = self.waitingQueue.popFirst() {
                waiting.succeed(())
            }
            return queuedJob
        }
    }

    public func pop(on eventLoop: EventLoop) -> EventLoopFuture<HBQueuedJob?> {
        self.eventLoop.flatSubmit {
            if self.waitingQueue.count > 0 || self.queue.count == 0 {
                let promise = self.eventLoop.makePromise(of: Void.self)
                self.waitingQueue.append(promise)
                return promise.futureResult.map { _ in
                    let value = self.queue.popFirst()!
                    return value
                }
            } else {
                let value = self.queue.popFirst()!
                return self.eventLoop.makeSucceededFuture(value)
            }
        }
    }
}
