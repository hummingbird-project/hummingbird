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

public struct HTTP1Channel: HBChannelSetup, HTTPChannelHandler {
    public typealias Value = NIOAsyncChannel<HTTPServerRequestPart, SendableHTTPServerResponsePart>

    public init(
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
        responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) {
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Value> {
        let childChannelHandlers: [RemovableChannelHandler] = self.additionalChannelHandlers() + [
            HBHTTPUserEventHandler(logger: logger),
            HBHTTPSendableResponseChannelHandler(),
        ]
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: false,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childChannelHandlers)
            return try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: .init()
            )
        }
    }

    public func handle(value asyncChannel: NIOCore.NIOAsyncChannel<NIOHTTP1.HTTPServerRequestPart, SendableHTTPServerResponsePart>, logger: Logging.Logger) async {
        await handleHTTP(asyncChannel: asyncChannel, logger: logger)
    }

    public var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}
