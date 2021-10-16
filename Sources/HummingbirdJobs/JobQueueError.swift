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

/// Job Queue Error type
public struct JobQueueError: Error, Equatable {
    /// failed to decode job. Possibly because it hasn't been registered or data that was expected
    /// is not available
    public static var decodeJobFailed: Self { .init(.decodeJobFailed) }

    private enum QueueError {
        case decodeJobFailed
    }

    private let error: QueueError

    private init(_ error: QueueError) {
        self.error = error
    }
}
