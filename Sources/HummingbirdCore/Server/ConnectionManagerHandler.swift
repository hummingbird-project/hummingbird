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

final class ConnectionManagerChannelHandler: ChannelDuplexHandler {
    public typealias InboundIn = Channel
    public typealias InboundOut = Channel
    public typealias OutboundIn = Never
    public typealias OutboundOut = Never

    enum State {
        case available
        case waitingOnAvailability
    }

    let maxConnections: Int
    var connectionCount: Int
    var state: State

    init(maxConnections: Int) {
        self.maxConnections = maxConnections
        self.connectionCount = 0
        self.state = .available
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channel = self.unwrapInboundIn(data)
        let loopBoundValues = NIOLoopBoundBox((handler: self, context: context), eventLoop: context.eventLoop)
        self.connectionCount += 1
        channel.closeFuture
            .hop(to: context.eventLoop)
            .whenComplete { _ in
                let values = loopBoundValues.value
                values.handler.connectionCount -= 1
                if values.handler.state == .waitingOnAvailability, values.handler.connectionCount < values.handler.maxConnections {
                    values.handler.state = .available
                    values.context.read()
                }
            }
        context.fireChannelRead(data)
    }

    public func read(context: ChannelHandlerContext) {
        print(self.connectionCount)
        guard self.connectionCount < self.maxConnections else {
            self.state = .waitingOnAvailability
            return
        }
        context.read()
    }
}
