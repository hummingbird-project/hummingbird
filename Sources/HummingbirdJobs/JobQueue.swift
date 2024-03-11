//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import NIOCore
import NIOFoundationCompat
import ServiceLifecycle

/// Job queue
///
/// Wrapper type to bring together a job queue implementation and a job queue
/// handler. Before you can push jobs onto a queue you should register it
/// with the queue via either ``JobQueue.registerJob(id:maxRetryCount:execute:)`` or
/// ``JobQueue.registerJob(_:)``.
public struct JobQueue<Queue: JobQueueDriver>: Service {
    /// underlying driver for queue
    public let queue: Queue
    let handler: JobQueueHandler<Queue>
    let allocator: ByteBufferAllocator

    public init(_ queue: Queue, numWorkers: Int = 1, logger: Logger) {
        self.queue = queue
        self.handler = .init(queue: queue, numWorkers: numWorkers, logger: logger)
        self.allocator = .init()
    }

    ///  Push Job onto queue
    /// - Parameters:
    ///   - id: Job identifier
    ///   - parameters: parameters for the job
    /// - Returns: Identifier of queued job
    @discardableResult public func push<Parameters: Codable & Sendable>(id: JobIdentifier<Parameters>, parameters: Parameters) async throws -> Queue.JobID {
        let jobRequest = JobRequest(id: id, parameters: parameters)
        let buffer = try JSONEncoder().encodeAsByteBuffer(jobRequest, allocator: self.allocator)
        let id = try await self.queue.push(buffer)
        self.handler.logger.debug("Pushed Job", metadata: ["_job_id": .stringConvertible(id), "_job_type": .string(jobRequest.id.name)])
        return id
    }

    ///  Register job type
    /// - Parameters:
    ///   - id: Job Identifier
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public func registerJob<Parameters: Codable & Sendable>(
        id: JobIdentifier<Parameters>,
        maxRetryCount: Int = 0,
        execute: @escaping @Sendable (
            Parameters,
            JobContext
        ) async throws -> Void
    ) {
        self.handler.logger.info("Registered Job", metadata: ["_job_type": .string(id.name)])
        let job = JobDefinition<Parameters>(id: id, maxRetryCount: maxRetryCount, execute: execute)
        self.registerJob(job)
    }

    ///  Register job type
    /// - Parameters:
    ///   - job: Job definition
    public func registerJob(_ job: JobDefinition<some Codable & Sendable>) {
        self.handler.registerJob(job)
    }

    ///  Run queue handler
    public func run() async throws {
        try await self.handler.run()
    }
}

extension JobQueue: CustomStringConvertible {
    public var description: String { "JobQueue<\(String(describing: Queue.self))>" }
}

/// Type used internally to encode a request
struct JobRequest<Parameters: Codable & Sendable>: Encodable, Sendable {
    let id: JobIdentifier<Parameters>
    let parameters: Parameters

    public init(id: JobIdentifier<Parameters>, parameters: Parameters) {
        self.id = id
        self.parameters = parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: _JobCodingKey.self)
        let childEncoder = container.superEncoder(forKey: .init(stringValue: self.id.name, intValue: nil))
        try self.parameters.encode(to: childEncoder)
    }
}
