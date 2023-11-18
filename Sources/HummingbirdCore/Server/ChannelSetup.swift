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

import Logging
import NIOCore
import NIOHTTP1

/// HTTPServer child channel setup protocol
public protocol HBChannelSetup: Sendable {
    associatedtype Value: Sendable

    /// Initialize channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value>

    /// handle async channel
    func handle(value: Value, logger: Logger) async
}
