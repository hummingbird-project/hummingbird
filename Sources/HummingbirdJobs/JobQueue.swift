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

/// Job queue protocol.
///
/// Defines how to push and pop jobs off a queue
public protocol HBJobQueue: AsyncSequence, Sendable where Element == HBQueuedJob<JobID> {
    associatedtype JobID: CustomStringConvertible & Sendable

    /// Called when JobQueueHandler is initialised with this queue
    func onInit() async throws
    /// Push Job onto queue
    /// - Returns: Identifier of queued job
    @discardableResult func _push(data: Data) async throws -> JobID
    /// This is called to say job has finished processing and it can be deleted
    func finished(jobId: JobID) async throws
    /// This is called to say job has failed to run and should be put aside
    func failed(jobId: JobID, error: any Error) async throws
    /// stop serving jobs
    func stop() async
    /// shutdown queue
    func shutdownGracefully() async
}

extension HBJobQueue {
    // default version of onInit doing nothing
    public func onInit() async throws {}
    /// Push Job onto queue
    /// - Returns: Identifier of queued job
    @discardableResult public func push<Parameters: Codable & Sendable>(id: HBJobIdentifier<Parameters>, parameters: Parameters) async throws -> JobID {
        let jobRequest = HBJobRequest(id: id, parameters: parameters)
        let data = try JSONEncoder().encode(jobRequest)
        return try await _push(data: data)
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
