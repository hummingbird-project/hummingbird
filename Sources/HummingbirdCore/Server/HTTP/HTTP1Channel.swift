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

import HTTPTypes
import Logging
import NIOCore
import NIOHTTPTypes
import NIOHTTPTypesHTTP1

/// Child channel for processing HTTP1
public struct HTTP1Channel: HBChildChannel, HTTPChannelHandler {
    public typealias Value = NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>

    ///  Initialize HTTP1Channel
    /// - Parameters:
    ///   - responder: Function returning a HTTP response for a HTTP request
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    public init(
        responder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse,
        additionalChannelHandlers: @escaping @Sendable () -> [any RemovableChannelHandler] = { [] }
    ) {
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    /// Setup child channel for HTTP1
    /// - Parameters:
    ///   - channel: Child channel
    ///   - configuration: Server configuration
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        let childChannelHandlers: [any ChannelHandler] =
            [HTTP1ToHTTPServerCodec(secure: false)] +
            self.additionalChannelHandlers() +
            [HBHTTPUserEventHandler(logger: logger)]
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

    /// handle HTTP messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value asyncChannel: NIOCore.NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>, logger: Logging.Logger) async {
        await handleHTTP(asyncChannel: asyncChannel, logger: logger)
    }

    public let responder: @Sendable (HBRequest, Channel) async throws -> HBResponse
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}
