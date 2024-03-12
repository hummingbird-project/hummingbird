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

/// Defines job parameters and identifier
public protocol JobParameters: Codable, Sendable {
    /// Job type identifier
    static var jobID: String { get }
}

extension JobQueue {
    ///  Push Job onto queue
    /// - Parameters:
    ///   - parameters: parameters for the job
    /// - Returns: Identifier of queued job
    @discardableResult public func push<Parameters: JobParameters>(_ parameters: Parameters) async throws -> Queue.JobID {
        return try await self.push(id: .init(Parameters.jobID), parameters: parameters)
    }

    ///  Register job type
    /// - Parameters:
    ///   - parameters: Job parameter type
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public func registerJob<Parameters: JobParameters>(
        parameters: Parameters.Type = Parameters.self,
        maxRetryCount: Int = 0,
        execute: @escaping @Sendable (
            Parameters,
            JobContext
        ) async throws -> Void
    ) {
        self.registerJob(id: .init(Parameters.jobID), maxRetryCount: maxRetryCount, execute: execute)
    }
}

extension JobDefinition where Parameters: JobParameters {
    ///  Initialize JobDefinition
    /// - Parameters:
    ///   - maxRetryCount: Maxiumum times this job will be retried if it fails
    ///   - execute: Closure that executes job
    public init(maxRetryCount: Int = 0, execute: @escaping @Sendable (Parameters, JobContext) async throws -> Void) {
        self.init(id: .init(Parameters.jobID), maxRetryCount: maxRetryCount, execute: execute)
    }
}
