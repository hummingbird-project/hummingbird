//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

struct TimeoutPromise<Value> {
    let task: Scheduled<Void>
    let promise: EventLoopPromise<Value>

    /// Create TimeoutPromise
    internal init(eventLoop: EventLoop, deadline: NIODeadline, file: StaticString, line: UInt) {
        let promise = eventLoop.makePromise(of: Value.self, file: file, line: line)
        self.promise = promise
        self.task = eventLoop.scheduleTask(deadline: deadline) { promise.fail(ChannelError.connectTimeout(.seconds(1))) }
    }

    /// Deliver a successful result to the associated `EventLoopFuture<Value>` object.
    ///
    /// - parameters:
    ///     - value: The successful result of the operation.
    @inlinable
    func succeed(_ value: Value) {
        self.promise.succeed(value)
    }

    /// Deliver an error to the associated `EventLoopFuture<Value>` object.
    ///
    /// - parameters:
    ///      - error: The error from the operation.
    @inlinable
    func fail(_ error: Error) {
        self.promise.fail(error)
    }

    /// Complete the promise with the passed in `EventLoopFuture<Value>`.
    ///
    /// This method is equivalent to invoking `future.cascade(to: promise)`,
    /// but sometimes may read better than its cascade counterpart.
    ///
    /// - parameters:
    ///     - future: The future whose value will be used to succeed or fail this promise.
    @inlinable
    func completeWith(_ future: EventLoopFuture<Value>) {
        self.promise.completeWith(future)
    }

    @inlinable
    var futureResult: EventLoopFuture<Value> { self.promise.futureResult }
}

extension EventLoop {
    /// Creates and returns a new `TimeoutPromise` that will be notified using this `EventLoop`
    /// or fail if it runs past the timeout
    func makeTimeoutPromise<Value>(of: Value.Type, timeout: TimeAmount, file: StaticString = #file, line: UInt = #line) -> TimeoutPromise<Value> {
        .init(eventLoop: self, deadline: .now() + timeout, file: file, line: line)
    }

    /// Creates and returns a new `TimeoutPromise` that will be notified using this `EventLoop`
    /// or fail it is runs past the deadline
    func makeTimeoutPromise<Value>(of: Value.Type, deadline: NIODeadline, file: StaticString = #file, line: UInt = #line) -> TimeoutPromise<Value> {
        .init(eventLoop: self, deadline: deadline, file: file, line: line)
    }
}
