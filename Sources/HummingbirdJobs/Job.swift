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
import NIO
import Logging

public protocol HBJob: Codable {
    /// Job name
    static var name: String { get }

    /// maximum times this job should be retried
    static var maxRetryCount: Int { get }

    /// Execute job
    /// - Parameter eventLoop: EventLoop to run job on
    func execute(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void>

    /// If the job fails after all retry attempts then this is called
    /// - Parameter eventLoop: EventLoop to run on
    func onError(_ error: Error, on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void>
}

extension HBJob {
    public func onError(_ error: Error, on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Void> {
        return eventLoop.makeFailedFuture(error)
    }

    /// maximum times this job should be retried
    public static var maxRetryCount: Int { return 1 }

    /// register job
    public static func register() {
        HBJobRegister.register(job: Self.self)
    }
}

/// Register Jobs, for decoding and encoding
enum HBJobRegister {
    static func decode(from decoder: Decoder) throws -> HBJob {
        let container = try decoder.container(keyedBy: _HBJobCodingKey.self)
        let key = container.allKeys.first!
        let childDecoder = try container.superDecoder(forKey: key)
        guard let jobType = HBJobRegister.nameTypeMap[key.stringValue] else { throw JobQueueError.decodeJobFailed }
        return try jobType.init(from: childDecoder)
    }

    static func encode(job: HBJob, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: _HBJobCodingKey.self)
        let childEncoder = container.superEncoder(forKey: .init(stringValue: type(of: job).name, intValue: nil))
        try job.encode(to: childEncoder)
    }

    static func register(job: HBJob.Type) {
        self.nameTypeMap[job.name] = job
    }

    static var nameTypeMap: [String: HBJob.Type] = [:]
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
