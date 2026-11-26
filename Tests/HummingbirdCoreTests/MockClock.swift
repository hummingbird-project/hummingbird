//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
//
// This source file is part of the valkey-swift project
// Copyright (c) 2025 the valkey-swift project authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
import DequeModule
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class MockClock: Clock {
    public struct Instant: InstantProtocol, Comparable {
        public typealias Duration = Swift.Duration

        public func advanced(by duration: Self.Duration) -> Self {
            .init(self.base + duration)
        }

        public func duration(to other: Self) -> Self.Duration {
            other.base - self.base
        }

        private var base: Swift.Duration

        public init(_ base: Duration) {
            self.base = base
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.base < rhs.base
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.base == rhs.base
        }
    }

    private struct State: Sendable {
        var now: Instant
    }

    public typealias Duration = Swift.Duration
    public var minimumResolution: Duration { .nanoseconds(1) }
    public var now: Instant { self.stateLock.withLock { $0.now } }

    private let stateLock = Mutex(State(now: .init(.seconds(0))))

    public init() {}

    public func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        preconditionFailure("Not implemented")
    }

    public func advance(to deadline: Instant) {
        self.stateLock.withLock {
            $0.now = deadline
        }
    }
}
