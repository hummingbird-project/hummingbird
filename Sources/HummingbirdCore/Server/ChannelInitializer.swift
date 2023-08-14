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

import NIOCore
import NIOHTTP1

/// HTTPServer child channel initializer protocol
public protocol HBChannelInitializer {
    /// Initialize channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void>

    ///  Add protocol upgrader to channel initializer
    /// - Parameter upgrader: HTTP server protocol upgrader to add
    mutating func addProtocolUpgrader(_ upgrader: HTTPServerProtocolUpgrader)
}

extension HBChannelInitializer {
    /// default to doing nothing
    public mutating func addProtocolUpgrader(_: HTTPServerProtocolUpgrader) {}
}

/// Setup child channel for HTTP1
public struct HTTP1Channel: HBChannelInitializer {
    public init(upgraders: [HTTPServerProtocolUpgrader] = []) {
        self.upgraders = upgraders
    }

    /// Initialize HTTP1 channel
    /// - Parameters:
    ///   - channel: channel
    ///   - childHandlers: Channel handlers to add
    ///   - configuration: server configuration
    public func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        var serverUpgrade: NIOHTTPServerUpgradeConfiguration?
        if self.upgraders.count > 0 {
            let loopBoundChildHandlers = NIOLoopBound(childHandlers, eventLoop: channel.eventLoop)
            serverUpgrade = (self.upgraders, { channel in
                // remove HTTP handlers after upgrade
                loopBoundChildHandlers.value.forEach {
                    _ = channel.pipeline.removeHandler($0)
                }
            })
        }
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: configuration.withPipeliningAssistance,
                withServerUpgrade: serverUpgrade,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childHandlers)
        }
    }

    ///  Add protocol upgrader to channel initializer
    /// - Parameter upgrader: HTTP server protocol upgrader to add
    public mutating func addProtocolUpgrader(_ upgrader: HTTPServerProtocolUpgrader) {
        self.upgraders.append(upgrader)
    }

    var upgraders: [HTTPServerProtocolUpgrader]
}
