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

public typealias HBAsyncChannelHandler<In, Out> = (NIOAsyncChannel<In, Out>) async -> Void

/// HTTPServer child channel setup protocol
public protocol HBChannelSetup: Sendable {
    associatedtype In: Sendable
    associatedtype Out: Sendable

    /// Initialize channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Void>

    /// handle async channel
    func handle(asyncChannel: NIOAsyncChannel<In, Out>, logger: Logger) async
}
