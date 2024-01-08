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

import ServiceLifecycle

/// Wrap another service to run after a preprocess closure has completed
struct PreprocessService<S: Service>: Service {
    let preprocess: @Sendable () async throws -> Void
    let service: S

    init(service: S, preprocess: @escaping @Sendable () async throws -> Void) {
        self.service = service
        self.preprocess = preprocess
    }

    func run() async throws {
        try await self.preprocess()
        try await self.service.run()
    }
}
