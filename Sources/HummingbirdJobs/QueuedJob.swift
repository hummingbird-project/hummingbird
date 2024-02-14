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
public struct HBAnyCodableJob: Codable, Sendable {
    /// Job data
    public let job: HBJob

    /// Initialize a queue job
    public init(_ job: HBJob) {
        self.job = job
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let jobDecoder = try container.superDecoder(forKey: .job)
        self.job = try HBJobRegister.decode(from: jobDecoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let jobEncoder = container.superEncoder(forKey: .job)
        try HBJobRegister.encode(job: self.job, to: jobEncoder)
    }

    private enum CodingKeys: String, CodingKey {
        case job
    }
}

/// Queued job. Includes job, plus the id for the job
public struct HBQueuedJob: Sendable, Codable {
    /// Job id
    public let id: JobIdentifier
    /// Job data
    private let _job: HBAnyCodableJob
    /// Job data
    public var job: HBJob { self._job.job }
    /// Job data in a codable form
    public var anyCodableJob: HBAnyCodableJob { self._job }

    /// Initialize a queue job
    public init(_ job: HBJob) {
        self._job = .init(job)
        self.id = .init()
    }

    /// Initialize a queue job
    public init(id: JobIdentifier, job: HBJob) {
        self._job = .init(job)
        self.id = id
    }
}
