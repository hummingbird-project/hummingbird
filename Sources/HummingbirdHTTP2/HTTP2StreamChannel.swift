//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTPTypes
import NIOHTTPTypesHTTP2

/// HTTP2 Child channel for processing an HTTP2 stream
struct HTTP2StreamChannel: ServerChildChannel {
    typealias Value = NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>
    typealias Configuration = HTTP1Channel.Configuration

    ///  Initialize HTTP2StreamChannel
    /// - Parameters:
    ///   - responder: Function returning a HTTP response for a HTTP request
    ///   - configuration: HTTP2 stream channel configuration
    init(
        responder: @escaping HTTPChannelHandler.Responder,
        configuration: Configuration = .init()
    ) {
        self.configuration = configuration
        self.responder = responder
    }

    /// Setup child channel for HTTP2 stream
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandler(HTTP2FramePayloadToHTTPServerCodec())
            try channel.pipeline.syncOperations.addHandlers(self.configuration.additionalChannelHandlers())
            if let idleTimeout = self.configuration.idleTimeout {
                try channel.pipeline.syncOperations.addHandler(IdleStateHandler(readTimeout: idleTimeout))
            }
            try channel.pipeline.syncOperations.addHandler(HTTPUserEventHandler(logger: logger))
            return try HTTP1Channel.Value(wrappingChannelSynchronously: channel)
        }
    }

    /// handle single HTTP request/response
    /// - Parameters:
    ///   - asyncChannel: NIOAsyncChannel handling HTTP parts
    ///   - logger: Logger to use while processing messages
    func handle(
        value asyncChannel: NIOCore.NIOAsyncChannel<HTTPRequestPart, HTTPResponsePart>,
        logger: Logging.Logger
    ) async {
        do {
            try await withTaskCancellationHandler {
                try await asyncChannel.executeThenClose { inbound, outbound in
                    var iterator = inbound.makeAsyncIterator()

                    // read first part, verify it is a head
                    guard let part = try await iterator.next() else { return }
                    guard case .head(let head) = part else {
                        throw HTTPChannelError.unexpectedHTTPPart(part)
                    }
                    let request = Request(
                        head: head,
                        bodyIterator: iterator,
                        supportCancelOnInboundClosure: self.configuration.supportCancelOnInboundClosure
                    )
                    let responseWriter = ResponseWriter(outbound: outbound)
                    try await self.responder(request, responseWriter, asyncChannel.channel)
                }
            } onCancel: {
                asyncChannel.channel.close(mode: .input, promise: nil)
            }
        } catch {
            // we got here because we failed to either read or write to the channel
            logger.trace("Failed to read/write to Channel. Error: \(error)")
        }
    }

    let responder: HTTPChannelHandler.Responder
    let configuration: Configuration
}
