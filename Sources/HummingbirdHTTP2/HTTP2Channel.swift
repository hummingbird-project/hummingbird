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
import NIOPosix
import NIOHTTP1
import NIOHTTP2
import Hummingbird
import HummingbirdCore
import NIOSSL

public struct HTTP2Channel: HTTPChannelHandler {
    public typealias Value = EventLoopFuture<NIONegotiatedHTTPVersion<HTTP1Channel.Value, (NIOAsyncChannel<HTTP2Frame, HTTP2Frame>, NIOHTTP2Handler.AsyncStreamMultiplexer<HTTP1Channel.Value>)>>

    private var tlsConfiguration: TLSConfiguration
    private var http1: HTTP1Channel
    public var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse {
        get { http1.responder }
        set { http1.responder = newValue }
    }

    public init(
        tlsConfiguration: TLSConfiguration,
        http1: HTTP1Channel = HTTP1Channel(),
        responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) {
        self.tlsConfiguration = tlsConfiguration
        self.http1 = http1
        // self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value> {
        channel.eventLoop.flatSubmit {
            do {
                let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
                try channel.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: sslContext))
            } catch {
                return channel.eventLoop.makeFailedFuture(error)
            }
            
            return channel.configureAsyncHTTPServerPipeline { http1Channel -> EventLoopFuture<HTTP1Channel.Value> in
                http1Channel
                    .pipeline
                    .addHandler(HBHTTPSendableResponseChannelHandler())
                    .flatMapThrowing {
                        try HTTP1Channel.Value(synchronouslyWrapping: http1Channel)
                    }
            } http2ConnectionInitializer: { http2Channel -> EventLoopFuture<NIOAsyncChannel<HTTP2Frame, HTTP2Frame>> in
                http2Channel.eventLoop.makeCompletedFuture {
                    try NIOAsyncChannel<HTTP2Frame, HTTP2Frame>(synchronouslyWrapping: http2Channel)
                }
            } http2StreamInitializer: { http2ChildChannel -> EventLoopFuture<HTTP1Channel.Value> in
                http2ChildChannel
                    .pipeline
                    .addHandlers(HTTP2FramePayloadToHTTP1ServerCodec(), HBHTTPSendableResponseChannelHandler())
                    .flatMapThrowing {
                        try HTTP1Channel.Value(synchronouslyWrapping: http2ChildChannel)
                    }
            }
        }
    }

    public func handle(value: Value, logger: Logger) async {
        do {
            let channel = try await value.get()
            switch channel {
            case .http1_1(let http1):
                await handleHTTP(asyncChannel: http1, logger: logger)
            case .http2((let http2, let multiplexer)):
                try await withThrowingDiscardingTaskGroup { group in
                    for try await client in multiplexer.inbound {
                        group.addTask {
                            await handleHTTP(asyncChannel: client, logger: logger)
                        }
                    }
                }

                try await http2.channel.close()
            }
        } catch {
            logger.error("Error handling inbound connection for HTTP2 handler: \(error)")
        }
    }
}
