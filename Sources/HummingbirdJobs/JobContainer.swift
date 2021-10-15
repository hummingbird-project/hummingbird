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

/// Holder for all data related to a job
public struct HBJobContainer: Codable {
    /// Time created
    public let createdAt: Date
    /// Job data
    public let job: HBJob

    /// Initialize a queue job
    init(_ job: HBJob) {
        self.job = job
        self.createdAt = Date()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        let jobDecoder = try container.superDecoder(forKey: .job)
        self.job = try HBJobRegister.decode(from: jobDecoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.createdAt, forKey: .createdAt)
        let jobEncoder = container.superEncoder(forKey: .job)
        try HBJobRegister.encode(job: self.job, to: jobEncoder)
    }

    private enum CodingKeys: String, CodingKey {
        case createdAt
        case job
    }
}

/// Queued job. Includes job, plus the id for the job
public struct HBQueuedJob {
    /// Job id
    public let id: JobIdentifier
    /// Job data
    public let job: HBJobContainer

    /// Initialize a queue job
    public init(_ job: HBJob) {
        self.job = .init(job)
        self.id = .init()
    }

    /// Initialize a queue job
    public init(id: JobIdentifier, job: HBJobContainer) {
        self.job = job
        self.id = id
    }
}
