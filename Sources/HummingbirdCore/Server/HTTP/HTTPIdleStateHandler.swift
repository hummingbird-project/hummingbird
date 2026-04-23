//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
public import NIOCore
public import NIOHTTPTypes

/// Triggers an IdleStateEvent when a Channel has not performed read, write, or both operation for a while.
public final class HTTPIdleStateHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPRequestPart
    public typealias InboundOut = HTTPRequestPart
    public typealias OutboundIn = HTTPResponsePart
    public typealias OutboundOut = HTTPResponsePart

    ///A user event triggered by IdleStateHandler when a Channel is idle.
    public enum IdleStateEvent: Sendable {
        /// Will be triggered when no read was performed for the specified amount of time
        case read
    }

    public let readTimeout: TimeAmount?

    private var reading = false
    private var lastReadTime: NIODeadline = .distantPast
    private var scheduledReaderTask: Optional<Scheduled<Void>>

    public init(readTimeout: TimeAmount? = nil, writeTimeout: TimeAmount? = nil, allTimeout: TimeAmount? = nil) {
        self.readTimeout = readTimeout
        self.scheduledReaderTask = nil
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive {
            initIdleTasks(context)
        }
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        cancelIdleTasks(context)
    }

    public func channelActive(context: ChannelHandlerContext) {
        initIdleTasks(context)
        context.fireChannelActive()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if readTimeout != nil {
            reading = true
        }
        context.fireChannelRead(data)
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        if (readTimeout != nil) && reading {
            lastReadTime = .now()
            reading = false
        }
        context.fireChannelReadComplete()
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        context.write(data, promise: promise)
    }

    private func shouldReschedule(_ context: ChannelHandlerContext) -> Bool {
        context.channel.isActive
    }

    private func makeReadTimeoutTask(_ context: ChannelHandlerContext, _ timeout: TimeAmount) -> (() -> Void) {
        {
            guard self.shouldReschedule(context) else {
                return
            }

            if self.reading {
                self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                    in: timeout,
                    self.makeReadTimeoutTask(context, timeout)
                )
                return
            }

            let diff = .now() - self.lastReadTime
            if diff >= timeout {
                // Reader is idle - set a new timeout and trigger an event through the pipeline
                self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                    in: timeout,
                    self.makeReadTimeoutTask(context, timeout)
                )

                context.fireUserInboundEventTriggered(IdleStateEvent.read)
            } else {
                // Read occurred before the timeout - set a new timeout with shorter delay.
                self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                    deadline: self.lastReadTime + timeout,
                    self.makeReadTimeoutTask(context, timeout)
                )
            }
        }
    }

    private func schedule(
        _ context: ChannelHandlerContext,
        _ amount: TimeAmount?,
        _ body: @escaping (ChannelHandlerContext, TimeAmount) -> (() -> Void)
    ) -> Scheduled<Void>? {
        if let timeout = amount {
            return context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(in: timeout, body(context, timeout))
        }
        return nil
    }

    private func initIdleTasks(_ context: ChannelHandlerContext) {
        let now = NIODeadline.now()
        lastReadTime = now
        scheduledReaderTask = schedule(context, readTimeout, makeReadTimeoutTask)
    }

    private func cancelIdleTasks(_ context: ChannelHandlerContext) {
        scheduledReaderTask?.cancel()
        scheduledReaderTask = nil
    }
}

@available(*, unavailable)
extension HTTPIdleStateHandler: Sendable {}
