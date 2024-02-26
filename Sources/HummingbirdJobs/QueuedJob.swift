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

/// Add codable support for decoding/encoding any HBJob
public struct HBAnyCodableJob: Decodable, Sendable {
    /// Job data
    public let job: any HBJob

    /// Initialize a queue job
    public init(_ job: any HBJob) {
        self.job = job
    }

    public init(from decoder: Decoder) throws {
        self.job = try HBJobRegister.decode(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case job
    }
}

/// Queued job. Includes job, plus the id for the job
public struct HBQueuedJob<JobID: Sendable>: Sendable {
    /// Job instance id
    public let id: JobID
    /// Job data
    public let job: any HBJob

    /// Initialize a queue job
    public init(id: JobID, job: any HBJob) {
        self.job = job
        self.id = id
    }
}
