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

import AsyncAlgorithms
import Atomics
import NIOCore

/// In memory driver for persist system for storing persistent cross request key/value pairs
public actor MemoryPersistDriver<C: Clock>: PersistDriver where C.Duration == Duration {
    public init(_ clock: C = .continuous) {
        self.values = [:]
        self.clock = clock
    }

    public func create(key: String, value: some Codable & Sendable, expires: Duration?) async throws {
        guard self.values[key] == nil else { throw PersistError.duplicate }
        self.values[key] = .init(value: value, expires: expires.map { self.clock.now.advanced(by: $0) })
    }

    public func set(key: String, value: some Codable & Sendable, expires: Duration?) async throws {
        let expiresAt = expires.map { self.clock.now.advanced(by: $0) } ?? self.values[key]?.expires
        self.values[key] = .init(value: value, expires: expiresAt)
    }

    public func get<Object: Codable & Sendable>(key: String, as: Object.Type) async throws -> Object? {
        guard let item = self.values[key] else { return nil }
        guard let expires = item.expires else { return item.value as? Object }
        guard self.clock.now <= expires else { return nil }
        return item.value as? Object
    }

    public func remove(key: String) async throws {
        self.values[key] = nil
    }

    /// Delete any values that have expired
    private func tidy() {
        let now = self.clock.now
        self.values = self.values.compactMapValues {
            if let expires = $0.expires {
                if expires > now {
                    return nil
                }
            }
            return $0
        }
    }

    struct Item {
        /// value stored
        let value: Codable & Sendable
        /// time when item expires
        let expires: C.Instant?

        init(value: Codable & Sendable, expires: C.Instant?) {
            self.value = value
            self.expires = expires
        }
    }

    public func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: .seconds(600), clock: .suspending)
            .cancelOnGracefulShutdown()
        for try await _ in timerSequence {
            self.tidy()
        }
    }

    var values: [String: Item]
    let clock: C
}
