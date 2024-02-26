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
public protocol HBJob: Sendable {
    /// Parameters job requries
    associatedtype Parameters: Codable & Sendable
    /// Job Type identifier
    var id: HBJobIdentifier<Parameters> { get }
    /// Maximum number of times a job will be retried before being classed as failed
    var maxRetryCount: Int { get }
    /// Function to execute the job
    func execute(context: HBJobContext) async throws
}

extension HBJob {
    /// name of job type
    public var name: String {
        id.name
    }
}

/// Type used internally by job queue implementations to encode a job request
public struct _HBJobRequest<Parameters: Codable & Sendable>: Encodable, Sendable {
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
