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

import HummingbirdCore
import NIOCore
import NIOHTTP1
import NIOHTTP2
import NIOSSL

/// Setup child channel for HTTP2
public struct HTTP2ChannelInitializer: HBChannelInitializer {
    public init() {}

    public func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { _ in
                streamChannel.pipeline.addHandlers(childHandlers)
            }
            .map { _ in }
        }
        .map { _ in }
    }
}

/// Setup child channel for HTTP2 upgrade
struct HTTP2UpgradeChannelInitializer: HBChannelInitializer {
    var http1 = HTTP1ChannelInitializer()
    let http2 = HTTP2ChannelInitializer()

    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        channel.configureHTTP2SecureUpgrade(
            h2ChannelConfigurator: { channel in
                http2.initialize(channel: channel, childHandlers: childHandlers, configuration: configuration)
            },
            http1ChannelConfigurator: { channel in
                http1.initialize(channel: channel, childHandlers: childHandlers, configuration: configuration)
            }
        )
    }

    ///  Add protocol upgrader to channel initializer
    /// - Parameter upgrader: HTTP server protocol upgrader to add
    public mutating func addProtocolUpgrader(_ upgrader: HTTPServerProtocolUpgrader) {
        self.http1.addProtocolUpgrader(upgrader)
    }
}
