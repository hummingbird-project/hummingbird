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
public struct JobIdentifier: Sendable, CustomStringConvertible, Codable {
    let id: String

    init() {
        self.id = UUID().uuidString
    }

    /// Initialize JobIdentifier from String
    /// - Parameter value: string value
    public init(_ value: String) {
        self.id = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.id = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }

    /// String description of Identifier
    public var description: String { self.id }
}

/// Job queue protocol.
///
/// Defines how to push and pop jobs off a queue
public protocol HBJobQueue: AnyObject {
    /// Process to run at initialisation of Job Queue
    /// - Returns: When queue initialisation is finished
    func onInit(on: EventLoop) -> EventLoopFuture<Void>
    /// Push Job onto queue
    /// - Returns: Queued job information
    func push(_ job: HBJob, on: EventLoop) -> EventLoopFuture<HBQueuedJob>
    /// Pop job off queue. Future will wait until a job is available
    /// - Returns: Queued job information
    func pop(on: EventLoop) -> EventLoopFuture<HBQueuedJob?>
    /// This is called to say job has finished processing and it can be deleted
    /// - Returns: When deletion of job has finished
    func finished(jobId: JobIdentifier, on: EventLoop) -> EventLoopFuture<Void>
    /// shutdown queue
    func shutdown(on: EventLoop) -> EventLoopFuture<Void>
    /// time amount between each poll of queue
    var pollTime: TimeAmount { get }
}

extension HBJobQueue {
    /// Default implememtatoin of `finish`. Does nothing
    /// - Parameters:
    ///   - jobId: Job Identifier
    ///   - eventLoop: EventLoop to run process on
    /// - Returns: When deletion of job has finished. In this case immediately
    public func finished(jobId: JobIdentifier, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.makeSucceededVoidFuture()
    }

    /// Default implementation of `onInit`. Does nothing
    /// - Parameter eventLoop: EventLoop to run process on
    /// - Returns: When initialisation has finished. In this case immediately
    public func onInit(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.makeSucceededVoidFuture()
    }

    /// Default implementation of `shutdown`. Does nothing
    public func shutdown(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
        return eventLoop.makeSucceededVoidFuture()
    }

    public var shutdownError: Error { return HBJobQueueShutdownError() }

    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job descriptor
    ///   - maxRetryCount: Number of times you should retry job
    /// - Returns: ID for job
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) -> EventLoopFuture<JobIdentifier> {
        return self.push(job, on: eventLoop).map(\.id)
    }

    /// Queue workers poll the queue to get the latest jobs off the queue. This indicates the time amount
    /// between each poll of the queue
    public var pollTime: TimeAmount { .milliseconds(100) }
}

/// Job queue asynchronous enqueue
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBJobQueue {
    /// Push job onto queue
    /// - Parameters:
    ///   - job: Job descriptor
    ///   - maxRetryCount: Number of times you should retry job
    /// - Returns: ID for job
    @discardableResult public func enqueue(_ job: HBJob, on eventLoop: EventLoop) async throws -> JobIdentifier {
        return try await self.push(job, on: eventLoop).map(\.id).get()
    }
}

/// Factory class for Job Queue drivers
/*public struct HBJobQueueFactory {
    let create: (HBApplication) -> HBJobQueue

    /// Initialize HBJobQueueFactory
    /// - Parameter create: Job Queue factory function
    public init(create: @escaping (HBApplication) -> HBJobQueue) {
        self.create = create
    }

    /// In memory driver for Job Queue system
    public static var memory: HBJobQueueFactory {
        .init(create: { app in HBMemoryJobQueue(eventLoop: app.eventLoopGroup.next()) })
    }
}*/

/// Error type for when a job queue is being shutdown
struct HBJobQueueShutdownError: Error {}
