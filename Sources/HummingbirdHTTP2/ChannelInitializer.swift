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
public struct HTTP2Channel: HBChannelInitializer {
    public init(tlsConfiguration: TLSConfiguration?) throws {
        if var tlsConfiguration = tlsConfiguration {
            tlsConfiguration.applicationProtocols.append("h2")
            tlsConfiguration.applicationProtocols.append("http/1.1")
            self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        } else {
            self.sslContext = nil
        }
    }

    public func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        if let sslContext = self.sslContext {
            do {
                try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: sslContext))
            } catch {
                return channel.eventLoop.makeFailedFuture(error)
            }
        }
        let loopBoundHandlers = NIOLoopBound(childHandlers, eventLoop: channel.eventLoop)
        return channel.configureHTTP2Pipeline(mode: .server) { streamChannel -> EventLoopFuture<Void> in
            return streamChannel.pipeline.addHandler(HTTP2FramePayloadToHTTP1ServerCodec()).flatMap { _ in
                streamChannel.pipeline.addHandlers(loopBoundHandlers.value)
            }
            .map { _ in }
        }
        .map { _ in }
    }

    let sslContext: NIOSSLContext?
}

/// Setup child channel for HTTP2 upgrade
struct HTTP2UpgradeChannel: HBChannelInitializer {
    var http1: HTTP1Channel
    let http2: HTTP2Channel
    let sslContext: NIOSSLContext

    public init(tlsConfiguration: TLSConfiguration, upgraders: [HTTPServerProtocolUpgrader] = []) throws {
        self.sslContext = try NIOSSLContext(configuration: tlsConfiguration)
        self.http1 = .init(upgraders: upgraders)
        self.http2 = try .init(tlsConfiguration: nil)
    }

    func initialize(channel: Channel, childHandlers: [RemovableChannelHandler], configuration: HBHTTPServer.Configuration) -> EventLoopFuture<Void> {
        do {
            try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: self.sslContext))
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
        }
        return channel.configureHTTP2SecureUpgrade(
            h2ChannelConfigurator: { channel in
                self.http2.initialize(channel: channel, childHandlers: childHandlers, configuration: configuration)
            },
            http1ChannelConfigurator: { channel in
                self.http1.initialize(channel: channel, childHandlers: childHandlers, configuration: configuration)
            }
        )
    }

    ///  Add protocol upgrader to channel initializer
    /// - Parameter upgrader: HTTP server protocol upgrader to add
    public mutating func addProtocolUpgrader(_ upgrader: HTTPServerProtocolUpgrader) {
        self.http1.addProtocolUpgrader(upgrader)
    }
}
