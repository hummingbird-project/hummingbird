//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
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
import ServiceLifecycle

/// Job queue
///
/// Wrapper type to bring together a job queue implementation and a job queue
/// handler. Before you can push jobs onto a queue you should register it
/// with the queue via either ``HBJobQueue.registerJob(id:maxRetryCount:execute:)`` or
/// ``HBJobQueue.registerJob(_:)``.
public struct HBJobQueue<Queue: HBJobQueueDriver>: Service {
    let queue: Queue
    let handler: HBJobQueueHandler<Queue>

    public init(_ queue: Queue, numWorkers: Int = 1, logger: Logger) {
        self.queue = queue
        self.handler = .init(queue: queue, numWorkers: numWorkers, logger: logger)
    }

    ///  Push Job onto queue
    /// - Parameters:
    ///   - id: Job identifier
    ///   - parameters: parameters for the job
    /// - Returns: Identifier of queued job
    @discardableResult public func push<Parameters: Codable & Sendable>(id: HBJobIdentifier<Parameters>, parameters: Parameters) async throws -> Queue.JobID {
        let jobRequest = HBJobRequest(id: id, parameters: parameters)
        let data = try JSONEncoder().encode(jobRequest)
        return try await self.queue.push(data: data)
    }

    ///  Register job
    /// - Parameters:
    ///   - id: Job Identifier
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public func registerJob<Parameters: Codable & Sendable>(
        _ id: HBJobIdentifier<Parameters>,
        maxRetryCount: Int = 0,
        execute: @escaping @Sendable (
            Parameters,
            HBJobContext
        ) async throws -> Void
    ) {
        let job = HBJobDefinition<Parameters>(id: id, maxRetryCount: maxRetryCount, execute: execute)
        self.handler.registerJob(job)
    }

    ///  Register job
    /// - Parameters:
    ///   - id: Job Identifier
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public func registerJob(_ job: HBJobDefinition<some Codable & Sendable>) {
        self.handler.registerJob(job)
    }

    ///  Run queue handler
    public func run() async throws {
        try await self.handler.run()
    }
}

/// Type used internally to encode a request
struct HBJobRequest<Parameters: Codable & Sendable>: Encodable, Sendable {
    let id: HBJobIdentifier<Parameters>
    let parameters: Parameters

    public init(id: HBJobIdentifier<Parameters>, parameters: Parameters) {
        self.id = id
        self.parameters = parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: _HBJobCodingKey.self)
        let childEncoder = container.superEncoder(forKey: .init(stringValue: self.id.name, intValue: nil))
        try self.parameters.encode(to: childEncoder)
    }
}
