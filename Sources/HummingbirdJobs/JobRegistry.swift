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

import Foundation
import NIOConcurrencyHelpers

/// Registry for job types
struct HBJobRegistry: Sendable {
    ///  Register job
    /// - Parameters:
    ///   - id: Job Identifier
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public func registerJob<Parameters: Codable & Sendable>(
        job: HBJobDefinition<Parameters>
    ) {
        let builder: @Sendable (Decoder) throws -> any HBJob = { decoder in
            let parameters = try Parameters(from: decoder)
            return try HBJobInstance<Parameters>(job: job, parameters: parameters)
        }
        self.builderTypeMap.withLockedValue {
            precondition($0[job.id.name] == nil, "There is a job already registered under id \"\(job.id.name)\"")
            $0[job.id.name] = builder
        }
    }

    func decode(data: Data) throws -> any HBJob {
        return try JSONDecoder().decode(HBAnyCodableJob.self, from: data, userInfoConfiguration: self).job
    }

    func decode(from decoder: Decoder) throws -> any HBJob {
        let container = try decoder.container(keyedBy: _HBJobCodingKey.self)
        let key = container.allKeys.first!
        let childDecoder = try container.superDecoder(forKey: key)
        let jobDefinitionBuilder = try self.builderTypeMap.withLockedValue {
            guard let job = $0[key.stringValue] else { throw JobQueueError.unrecognisedJobId }
            return job
        }
        return try jobDefinitionBuilder(childDecoder)
    }

    let builderTypeMap: NIOLockedValueBox < [String: @Sendable (Decoder) throws -> any HBJob]> = .init([:])
}

/// Internal job instance type
internal struct HBJobInstance<Parameters: Codable & Sendable>: HBJob {
    /// job definition
    let job: HBJobDefinition<Parameters>
    /// job parameters
    let parameters: Parameters

    /// get i
    var id: HBJobIdentifier<Parameters> { self.job.id }
    var maxRetryCount: Int { self.job.maxRetryCount }

    func execute(context: HBJobContext) async throws {
        try await self.job.execute(self.parameters, context: context)
    }

    init(job: HBJobDefinition<Parameters>, parameters: Parameters) throws {
        self.job = job
        self.parameters = parameters
    }
}

/// Add codable support for decoding/encoding any HBJob
internal struct HBAnyCodableJob: DecodableWithUserInfoConfiguration, Sendable {
    typealias DecodingConfiguration = HBJobRegistry

    init(from decoder: Decoder, configuration register: DecodingConfiguration) throws {
        self.job = try register.decode(from: decoder)
    }

    /// Job data
    let job: any HBJob

    /// Initialize a queue job
    init(_ job: any HBJob) {
        self.job = job
    }

    private enum CodingKeys: String, CodingKey {
        case job
    }
}

internal struct _HBJobCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    internal init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
}
