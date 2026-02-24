//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import AsyncAlgorithms
import Atomics
import NIOCore
import ServiceLifecycle

/// In memory driver for persist system for storing persistent cross request key/value pairs
@available(macOS 14, iOS 17, tvOS 17, *)
public actor MemoryPersistDriver<C: Clock>: PersistDriver where C.Duration == Duration {
    public struct Configuration: Sendable {
        /// amount of time between each call to tidy
        public var tidyFrequency: Duration

        ///  Initialize MemoryPersistDriver configuration
        /// - Parameter tidyFrequency:
        public init(tidyFrequency: Duration = .seconds(600)) {
            self.tidyFrequency = tidyFrequency
        }
    }

    /// Initialize MemoryPersistDriver
    /// - Parameters:
    ///   - clock: Clock to use when calculating expiration dates
    @_disfavoredOverload
    public init(_ clock: C = .continuous) {
        self.values = [:]
        self.clock = clock
        self.configuration = .init()
    }

    /// Initialize MemoryPersistDriver
    /// - Parameters:
    ///   - clock: Clock to use when calculating expiration dates
    ///   - configuration: Configuration of driver
    public init(_ clock: C = .continuous, configuration: Configuration = .init()) {
        self.values = [:]
        self.clock = clock
        self.configuration = configuration
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
        if let expires = item.expires {
            guard self.clock.now <= expires else { return nil }
        }
        guard let object = item.value as? Object else { throw PersistError.invalidConversion }
        return object
    }

    public func remove(key: String) async throws {
        self.values[key] = nil
    }

    /// Delete any values that have expired
    private func tidy() {
        let now = self.clock.now
        self.values = self.values.compactMapValues {
            if let expires = $0.expires {
                if expires < now {
                    return nil
                }
            }
            return $0
        }
    }

    struct Item {
        /// value stored
        let value: any Codable & Sendable
        /// time when item expires
        let expires: C.Instant?

        init(value: any Codable & Sendable, expires: C.Instant?) {
            self.value = value
            self.expires = expires
        }
    }

    public func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: self.configuration.tidyFrequency, clock: self.clock)
            .cancelOnGracefulShutdown()
        for try await _ in timerSequence {
            self.tidy()
        }
    }

    var values: [String: Item]
    let clock: C
    let configuration: Configuration
}
