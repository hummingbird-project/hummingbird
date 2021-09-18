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
import NIOHTTP2
import NIOSSL

/// HTTP2 channel initializer
struct HTTP2ChannelInitializer: HBChannelInitializer {
    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { _ in
                streamChannel.pipeline.addHandlers(childHandlers)
            }
            .map { _ in }
        }
        .map { _ in }
    }
}

/// HTTP2 upgrade channel initializer
struct HTTP2UpgradeChannelInitializer: HBChannelInitializer {
    let http1 = HTTP1ChannelInitializer()
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
}
