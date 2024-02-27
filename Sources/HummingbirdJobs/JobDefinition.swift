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
public struct HBJobDefinition<Parameters: Codable & Sendable>: Sendable {
    public let id: HBJobIdentifier<Parameters>
    let maxRetryCount: Int
    let _execute: @Sendable (Parameters, HBJobContext) async throws -> Void

    public init(id: HBJobIdentifier<Parameters>, maxRetryCount: Int = 0, execute: @escaping @Sendable (Parameters, HBJobContext) async throws -> Void) {
        self.id = id
        self.maxRetryCount = maxRetryCount
        self._execute = execute
    }

    func execute(_ parameters: Parameters, context: HBJobContext) async throws {
        try await self._execute(parameters, context)
    }
}
