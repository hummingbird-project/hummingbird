//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Task has timed out error
public struct TimeoutError: Error {}

/// Run task with a timeout
///
/// Task needs to support cancellation
/// - Parameters:
///   - timeout: Amount of time allowed for the task to run
///   - process: Task to run
/// - Returns: Result of task
public func withTimeout<T>(timeout: Duration, _ process: @escaping @Sendable () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await process()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError()
        }
        defer {
            group.cancelAll()
        }
        return try await group.next()!
    }
}

/// Async version of expectation.
///
/// A counter that you can wait upon it hitting zero. Similar to XCTExpectation but works in
/// async environment on both macOS and Linux
public actor AsyncExpectation: Sendable {
    var value: Int
    var continuation: CheckedContinuation<Void, Error>?

    public init(_ value: Int) {
        self.value = value
        self.continuation = nil
    }

    public func fulfill() {
        precondition(self.value > 0, "Cannot call decrement on Counter that has already hit zero")
        self.value -= 1
        if self.value == 0, let continuation = continuation {
            continuation.resume()
            self.continuation = nil
        }
    }

    public func wait() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task {
                await self.continuation?.resume(throwing: CancellationError())
            }
        }
    }
}
