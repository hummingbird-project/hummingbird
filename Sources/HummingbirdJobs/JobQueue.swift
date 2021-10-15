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
import Hummingbird
import Logging

/// Identifier for Job
public struct JobIdentifier: CustomStringConvertible {
    let id: String

    init() {
        self.id = UUID().uuidString
    }

    public init(_ value: String) {
        self.id = value
    }

    public var description: String { self.id }
}

/// Job queue protocol
public protocol HBJobQueue: AnyObject {
    /// - Parameter job: job descriptor
    func push(_ job: HBJob, on: EventLoop) -> EventLoopFuture<HBQueuedJob>
    /// Pop job off queue. Future will wait until a job is available
    func pop(on: EventLoop) -> EventLoopFuture<HBQueuedJob?>
    /// Process to run at initialisation
    func onInit(on: EventLoop) -> EventLoopFuture<Void>
    /// finished
    func finished(jobId: JobIdentifier, on: EventLoop) -> EventLoopFuture<Void>
    /// shutdown queue
    func shutdown()
    /// time amount between each poll of queue
    var pollTime: TimeAmount { get }
}

extension HBJobQueue {
    /// default finished does nothing
    public func finished(jobId: JobIdentifier, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.makeSucceededVoidFuture()
    }

    /// default finished does nothing
    public func onInit(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.makeSucceededVoidFuture()
    }

    /// default shutdown does nothing
    public func shutdown() {}

    public var shutdownError: Error { return HBJobQueueShutdownError() }

    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job descriptor
    ///   - maxRetryCount: Number of times you should retry job
    /// - Returns: ID for job
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) -> EventLoopFuture<JobIdentifier> {
        return self.push(job, on: eventLoop).map(\.id)
    }

    /// time amount between each poll of queue
    public var pollTime: TimeAmount { .milliseconds(100) }
}

/// Factory class for persist drivers
public struct HBJobQueueFactory {
    public let create: (HBApplication) -> HBJobQueue

    /// Initialize HBPersistDriverFactory
    /// - Parameter create: HBPersistDriver factory function
    public init(create: @escaping (HBApplication) -> HBJobQueue) {
        self.create = create
    }

    /// In memory driver for persist system
    public static var memory: HBJobQueueFactory {
        .init(create: { app in HBMemoryJobQueue(eventLoopGroup: app.eventLoopGroup) })
    }
}

struct HBJobQueueShutdownError: Error {}
