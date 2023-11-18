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

public class HBHTTPUserEventHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias InboundOut = HTTPServerRequestPart
    public typealias OutboundIn = HTTPServerResponsePart
    public typealias OutboundOut = HTTPServerResponsePart

    var closeAfterResponseWritten: Bool = false
    var requestsBeingRead: Int = 0
    var requestsInProgress: Int = 0
    let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        if case .end = part {
            self.requestsInProgress -= 1
            context.write(data, promise: promise)
            if self.closeAfterResponseWritten {
                context.close(promise: nil)
                self.closeAfterResponseWritten = false
            }
        } else {
            context.write(data, promise: promise)
        }
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)
        switch part {
        case .head:
            self.requestsInProgress += 1
            self.requestsBeingRead += 1
        case .end:
            self.requestsBeingRead -= 1
        default:
            break
        }
        context.fireChannelRead(data)
    }

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case IdleStateHandler.IdleStateEvent.read:
            // if we get an idle read event and we haven't completed reading the request
            // close the connection
            if self.requestsBeingRead > 0 {
                self.logger.trace("Idle read timeout, so close channel")
                context.close(promise: nil)
            }

        case IdleStateHandler.IdleStateEvent.write:
            // if we get an idle write event and are not currently processing a request
            if self.requestsInProgress == 0 {
                self.logger.trace("Idle write timeout, so close channel")
                context.close(mode: .input, promise: nil)
            }

        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}
