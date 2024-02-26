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

import NIOConcurrencyHelpers

/// Registry for job types
public enum HBJobRegister {
    ///  Register job
    /// - Parameters:
    ///   - id: Job Identifier
    ///   - maxRetryCount: Maximum number of times job is retried before being flagged as failed
    ///   - execute: Job code
    public static func registerJob<Parameters: Codable & Sendable>(
        _ id: HBJobIdentifier<Parameters>,
        maxRetryCount: Int = 0,
        execute: @escaping @Sendable (
            Parameters,
            HBJobContext
        ) async throws -> Void
    ) {
        let definition = HBJobInstance<Parameters>.Definition(id: id, maxRetryCount: maxRetryCount, execute: execute)
        let builder = { (decoder: Decoder) in
            let parameters = try Parameters(from: decoder)
            return try HBJobInstance(job: definition, parameters: parameters)
        }
        self.idTypeMap.withLockedValue {
            precondition($0[id.name] == nil, "There is a job already registered under id \"\(id.name)\"")
            $0[id.name] = builder
        }
    }

    static func decode(from decoder: Decoder) throws -> any HBJob {
        let container = try decoder.container(keyedBy: _HBJobCodingKey.self)
        let key = container.allKeys.first!
        let childDecoder = try container.superDecoder(forKey: key)
        let jobDefinitionBuilder = try Self.idTypeMap.withLockedValue {
            guard let job = $0[key.stringValue] else { throw JobQueueError.decodeJobFailed }
            return job
        }
        return try jobDefinitionBuilder(childDecoder)
    }

    static let idTypeMap: NIOLockedValueBox < [String: (Decoder) throws -> any HBJob]> = .init([:])
}

/// Internal job instance type
struct HBJobInstance<Parameters: Codable & Sendable>: HBJob {
    /// Job definition type
    struct Definition {
        let id: HBJobIdentifier<Parameters>
        let maxRetryCount: Int
        let _execute: @Sendable (Parameters, HBJobContext) async throws -> Void

        init(id: HBJobIdentifier<Parameters>, maxRetryCount: Int, execute: @escaping @Sendable (Parameters, HBJobContext) async throws -> Void) {
            self.id = id
            self.maxRetryCount = maxRetryCount
            self._execute = execute
        }

        public func execute(_ parameters: Parameters, context: HBJobContext) async throws {
            try await self._execute(parameters, context)
        }
    }

    /// job definition
    let job: Definition
    /// job parameters
    let parameters: Parameters

    /// get i
    var id: HBJobIdentifier<Parameters> { self.job.id }
    var maxRetryCount: Int { self.job.maxRetryCount }

    func execute(context: HBJobContext) async throws {
        try await self.job.execute(self.parameters, context: context)
    }

    init(job: Definition, parameters: Parameters) throws {
        self.job = job
        self.parameters = parameters
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
