//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Protocol for a Job
protocol Job: Sendable {
    /// Parameters job requries
    associatedtype Parameters: Codable & Sendable
    /// Job Type identifier
    var id: JobIdentifier<Parameters> { get }
    /// Maximum number of times a job will be retried before being classed as failed
    var maxRetryCount: Int { get }
    /// Function to execute the job
    func execute(context: JobContext) async throws
}

extension Job {
    /// name of job type
    public var name: String {
        id.name
    }
}
