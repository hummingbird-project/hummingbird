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

import Hummingbird

extension HBRequest {
    public struct Jobs {
        public func enqueue(job: HBJob, on queue: HBApplication.JobQueueHandler.QueueKey = .default) -> EventLoopFuture<JobIdentifier> {
            self.request.application.jobs.queues(queue).enqueue(job, on: self.request.eventLoop)
        }

        let request: HBRequest
    }

    public var jobs: Jobs { .init(request: self) }
}
