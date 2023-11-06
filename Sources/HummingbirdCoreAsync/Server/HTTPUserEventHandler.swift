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

class HBHTTPUserEventHandler: ChannelDuplexHandler, RemovableChannelHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPServerRequestPart
    typealias OutboundIn = HTTPServerResponsePart
    typealias OutboundOut = HTTPServerResponsePart

    var closeAfterResponseWritten: Bool = false
    var requestsBeingRead: Int = 0
    var requestsInProgress: Int = 0
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        if case .end = part {
            self.requestsInProgress -= 1
            context.writeAndFlush(data, promise: promise)
            if self.closeAfterResponseWritten {
                context.close(promise: nil)
                self.closeAfterResponseWritten = false
            }
        } else {
            context.writeAndFlush(data, promise: promise)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
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
        if case .head = part {
            self.requestsInProgress += 1
        }
        context.fireChannelRead(data)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ChannelShouldQuiesceEvent:
            // we received a quiesce event. If we have any requests in progress we should
            // wait for them to finish.
            //
            // If we are running with the HTTP pipeline assistance handler then we will never
            // receive quiesce events but in the case where we aren't this is needed
            if self.requestsInProgress > 0 {
                self.closeAfterResponseWritten = true
            } else {
                context.close(promise: nil)
            }

        case let evt as IdleStateHandler.IdleStateEvent where evt == .read:
            // if we get an idle read event and we haven't completed reading the request
            // close the connection
            if self.requestsBeingRead > 0 {
                self.logger.trace("Idle read timeout, so close channel")
                context.close(promise: nil)
            }

        case let evt as IdleStateHandler.IdleStateEvent where evt == .write:
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
