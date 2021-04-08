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

extension EventLoopGroup {
    /// Run closure on every EventLoop in an EventLoopGroup and return results in an array of `EventLoopFuture`s.
    func map<T>(_ transform: @escaping (EventLoop) -> T) -> [EventLoopFuture<T>] {
        var array: [EventLoopFuture<T>] = []
        for eventLoop in self.makeIterator() {
            let result = eventLoop.submit {
                transform(eventLoop)
            }
            array.append(result)
        }
        return array
    }

    /// Run closure returning `EventLoopFuture` on every EventLoop in an EventLoopGroup and return results in an array of `EventLoopFuture`s.
    func flatMap<T>(_ transform: @escaping (EventLoop) -> EventLoopFuture<T>) -> [EventLoopFuture<T>] {
        var array: [EventLoopFuture<T>] = []
        for eventLoop in self.makeIterator() {
            let result = eventLoop.flatSubmit {
                transform(eventLoop)
            }
            array.append(result)
        }
        return array
    }
}
