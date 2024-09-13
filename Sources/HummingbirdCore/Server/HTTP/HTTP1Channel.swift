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
public struct HTTP1Channel: ServerChildChannel, HTTPChannelHandler {
    public typealias Value = NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>

    ///  Initialize HTTP1Channel
    /// - Parameters:
    ///   - responder: Function returning a HTTP response for a HTTP request
    ///   - additionalChannelHandlers: Additional channel handlers to add to channel pipeline
    public init(
        responder: @escaping HTTPChannelHandler.Responder,
        additionalChannelHandlers: @escaping @Sendable () -> [any RemovableChannelHandler] = { [] }
    ) {
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    /// Setup child channel for HTTP1
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        let childChannelHandlers: [any ChannelHandler] =
            [HTTP1ToHTTPServerCodec(secure: false)] + self.additionalChannelHandlers() + [
                HTTPUserEventHandler(logger: logger),
            ]
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: false, // HTTP is pipelined by NIOAsyncChannel
                withErrorHandling: true,
                withOutboundHeaderValidation: false // Swift HTTP Types are already doing this validation
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
    ///   - asyncChannel: NIOAsyncChannel handling HTTP parts
    ///   - logger: Logger to use while processing messages
    public func handle(
        value asyncChannel: NIOCore.NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>,
        logger: Logging.Logger
    ) async {
        await handleHTTP(asyncChannel: asyncChannel, logger: logger)
    }

    public let responder: HTTPChannelHandler.Responder
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}

/// Extend NIOAsyncChannel to ServerChildChannelValue so it can be used in a ServerChildChannel
extension NIOAsyncChannel: ServerChildChannelValue {}
