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

import NIOCore
import NIOHTTP1

/// Sendable server response that doesn't use ``IOData``
public typealias SendableHTTPServerResponsePart = HTTPPart<HTTPResponseHead, ByteBuffer>

/// Channel to convert HTTPServerResponsePart to the Sendable type HBHTTPServerResponsePart
public final class HBHTTPSendableResponseChannelHandler: ChannelOutboundHandler, RemovableChannelHandler {
    public typealias OutboundIn = SendableHTTPServerResponsePart
    public typealias OutboundOut = HTTPServerResponsePart

    public init() {}

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        switch part {
        case .head(let head):
            context.write(self.wrapOutboundOut(.head(head)), promise: promise)
        case .body(let buffer):
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        case .end:
            context.write(self.wrapOutboundOut(.end(nil)), promise: promise)
        }
    }
}
