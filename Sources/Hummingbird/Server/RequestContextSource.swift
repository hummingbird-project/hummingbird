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

import Logging
import NIOCore

/// Protocol for source of request contexts
public protocol RequestContextSource {
    /// Request Logger
    var logger: Logger { get }
}

/// RequestContext source for contexts created by ``Application``.
public struct ApplicationRequestContextSource: RequestContextSource {
    public init(channel: any Channel, logger: Logger) {
        self.channel = channel
        self.logger = logger
    }

    public let channel: any Channel
    public let logger: Logger
}
