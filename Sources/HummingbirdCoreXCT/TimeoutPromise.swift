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

import NIO

public struct TimeoutPromise {
    let task: Scheduled<Void>
    let promise: EventLoopPromise<Void>

    public init(eventLoop: EventLoop, timeout: TimeAmount) {
        let promise = eventLoop.makePromise(of: Void.self)
        self.promise = promise
        self.task = eventLoop.scheduleTask(in: timeout) { promise.fail(ChannelError.connectTimeout(timeout)) }
    }

    public func succeed() {
        self.promise.succeed(())
    }

    public func fail(_ error: Error) {
        self.promise.fail(error)
    }

    public func wait() throws {
        try self.promise.futureResult.wait()
        self.task.cancel()
    }
}
