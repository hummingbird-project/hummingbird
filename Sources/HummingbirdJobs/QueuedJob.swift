//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIOCore

/// Queued job. Includes job data, plus the id for the job
public struct HBQueuedJob<JobID: Sendable>: Sendable {
    /// Job instance id
    public let id: JobID
    /// Job data
    public let jobBuffer: ByteBuffer

    /// Initialize a queue job
    public init(id: JobID, jobBuffer: ByteBuffer) {
        self.jobBuffer = jobBuffer
        self.id = id
    }
}
