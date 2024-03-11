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

/// Job definition type
public struct JobDefinition<Parameters: Codable & Sendable>: Sendable {
    public let id: JobIdentifier<Parameters>
    let maxRetryCount: Int
    let _execute: @Sendable (Parameters, JobContext) async throws -> Void

    public init(id: JobIdentifier<Parameters>, maxRetryCount: Int = 0, execute: @escaping @Sendable (Parameters, JobContext) async throws -> Void) {
        self.id = id
        self.maxRetryCount = maxRetryCount
        self._execute = execute
    }

    func execute(_ parameters: Parameters, context: JobContext) async throws {
        try await self._execute(parameters, context)
    }
}
