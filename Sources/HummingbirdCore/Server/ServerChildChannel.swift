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
import ServiceLifecycle

public protocol ChildChannelValue: Sendable {
    var eventLoop: EventLoop { get }
}

/// HTTPServer child channel setup protocol
public protocol ServerChildChannel: Sendable {
    associatedtype Value: ChildChannelValue

    /// Setup child channel
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value>

    /// handle messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    func handle(value: Value, logger: Logger) async
}

extension ServerChildChannel {
    /// Build existential ``Server`` from existential `ServerChildChannel`
    ///
    /// - Parameters:
    ///   - configuration: Configuration for server
    ///   - onServerRunning: Closure to run once server is up and running
    ///   - eventLoopGroup: EventLoopGroup the server uses
    ///   - logger: Logger used by server
    /// - Returns: Server Service
    public func server(
        configuration: ServerConfiguration,
        onServerRunning: (@Sendable (Channel) async -> Void)? = { _ in },
        eventLoopGroup: EventLoopGroup,
        logger: Logger
    ) -> Service {
        Server(
            childChannelSetup: self,
            configuration: configuration,
            onServerRunning: onServerRunning,
            eventLoopGroup: eventLoopGroup,
            logger: logger
        )
    }
}
