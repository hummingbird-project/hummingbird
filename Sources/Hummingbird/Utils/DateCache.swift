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
import NIOPosix
import ServiceLifecycle

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Current date formatted cache service
///
/// Getting the current date formatted is an expensive operation. This creates a task that will
/// update a cached version of the date in the format as detailed in RFC9110 once every second.
@available(macOS 14, iOS 17, tvOS 17, *)
final class DateCache: Service {
    final class DateContainer: AtomicReference, Sendable {
        let date: String

        init(date: String) {
            self.date = date
        }
    }

    let dateContainer: ManagedAtomic<DateContainer>

    init() {
        self.dateContainer = .init(.init(date: Date.now.httpHeader))
    }

    public func run() async throws {
        let timerSequence = AsyncTimerSequence(interval: .seconds(1), clock: .suspending)
            .cancelOnGracefulShutdown()
        for try await _ in timerSequence {
            self.dateContainer.store(.init(date: Date.now.httpHeader), ordering: .releasing)
        }
    }

    public var date: String {
        self.dateContainer.load(ordering: .acquiring).date
    }
}
