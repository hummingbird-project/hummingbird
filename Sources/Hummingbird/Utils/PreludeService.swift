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

/// Wrap another service to run after a prelude closure has completed
struct PreludeService<S: Service>: Service, CustomStringConvertible {
    let prelude: @Sendable () async throws -> Void
    let service: S

    var description: String {
        "PreludeService<\(S.self)>"
    }

    init(service: S, prelude: @escaping @Sendable () async throws -> Void) {
        self.service = service
        self.prelude = prelude
    }

    func run() async throws {
        try await self.prelude()
        try await self.service.run()
    }
}

extension Service {
    /// Build existential ``PreludeService`` from an existential `Service`
    func withPrelude(_ prelude: @escaping @Sendable () async throws -> Void) -> Service {
        PreludeService(service: self, prelude: prelude)
    }
}
