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

import ServiceLifecycle

/// Wrap another service to run after a precursor closure has completed
struct PrecursorService<S: Service>: Service, CustomStringConvertible {
    let precursor: @Sendable () async throws -> Void
    let service: S

    var description: String {
        "PrecursorService<\(S.self)>"
    }

    init(service: S, process: @escaping @Sendable () async throws -> Void) {
        self.service = service
        self.precursor = process
    }

    func run() async throws {
        try await self.precursor()
        try await self.service.run()
    }
}
