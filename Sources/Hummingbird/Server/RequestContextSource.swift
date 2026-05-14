//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import Logging
public import NIOCore

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
