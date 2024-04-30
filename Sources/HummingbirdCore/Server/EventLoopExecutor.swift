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

import NIOCore

#if compiler(>=6.0)
    final class EventLoopExecutor: TaskExecutor, SerialExecutor {
        @usableFromInline let eventLoop: EventLoop

        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }

        func asUnownedTaskExecutor() -> UnownedTaskExecutor {
            UnownedTaskExecutor(ordinary: self)
        }

        @inlinable
        func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)
            self.eventLoop.execute {
                job.runSynchronously(on: self.asUnownedTaskExecutor())
            }
        }

        @inlinable
        func asUnownedSerialExecutor() -> UnownedSerialExecutor {
            UnownedSerialExecutor(complexEquality: self)
        }

        @inlinable
        func isSameExclusiveExecutionContext(other: EventLoopExecutor) -> Bool {
            self.eventLoop === other.eventLoop
        }
    }
#endif  // swift(>=6.0)
