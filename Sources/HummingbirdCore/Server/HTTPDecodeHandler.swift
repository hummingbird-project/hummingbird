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

import NIO
import NIOHTTP1

/// Channel handler for decoding HTTP parts into a HTTP request
final class HBHTTPDecodeHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HBHTTPRequest
    public typealias OutboundIn = Never
    public typealias OutboundOut = HTTPServerResponsePart

    enum State {
        case idle
        case head(HTTPRequestHead)
        case body(HTTPRequestHead, ByteBuffer)
        case streamingBody(HBRequestBodyStreamer)
        case error
    }

    let maxUploadSize: Int
    let maxStreamingBufferSize: Int

    /// handler state
    var state: State

    init(configuration: HBHTTPServer.Configuration) {
        self.maxUploadSize = configuration.maxUploadSize
        self.maxStreamingBufferSize = configuration.maxStreamingBufferSize
        self.state = .idle
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch (part, self.state) {
        case (.head(let head), .idle):
            self.state = .head(head)

        case (.body(let part), .head(let head)):
            self.state = .body(head, part)

        case (.body(let part), .body(let head, let buffer)):
            let streamer = HBRequestBodyStreamer(eventLoop: context.eventLoop, maxSize: self.maxUploadSize)
            let request = HBHTTPRequest(head: head, body: .stream(streamer))
            streamer.feed(.byteBuffer(buffer))
            streamer.feed(.byteBuffer(part))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .streamingBody(streamer)

        case (.body(let part), .streamingBody(let streamer)):
            streamer.feed(.byteBuffer(part))
            self.state = .streamingBody(streamer)

        case (.end, .head(let head)):
            let request = HBHTTPRequest(head: head, body: .byteBuffer(nil))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .idle

        case (.end, .body(let head, let buffer)):
            let request = HBHTTPRequest(head: head, body: .byteBuffer(buffer))
            context.fireChannelRead(self.wrapInboundOut(request))
            self.state = .idle

        case (.end, .streamingBody(let streamer)):
            streamer.feed(.end)
            self.state = .idle

        case (.end, .error):
            self.state = .idle

        case (_, .error):
            break

        default:
            assertionFailure("Should not get here")
            context.close(promise: nil)
        }
    }

    func read(context: ChannelHandlerContext) {
        if case .streamingBody(let streamer) = self.state {
            guard streamer.currentSize < self.maxStreamingBufferSize else {
                streamer.onConsume = { streamer in
                    if streamer.currentSize < self.maxStreamingBufferSize {
                        context.read()
                    }
                }
                return
            }
        }
        context.read()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        switch self.state {
        case .streamingBody(let streamer):
            // request has already been forwarded to next hander have to pass error via streamer
            streamer.feed(.error(error))
            // only set state to error if already streaming a request body. Don't want to feed
            // additional ByteBuffers to streamer if error has been set
            self.state = .error
        default:
            context.fireErrorCaught(error)
        }
    }
}
