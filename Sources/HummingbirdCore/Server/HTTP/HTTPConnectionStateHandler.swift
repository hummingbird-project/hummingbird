//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
public import Logging
public import NIOCore
public import NIOHTTPTypes

/// Triggers an IdleStateEvent when a Channel has not performed read, write, or both operation for a while.
@available(hummingbird 2.0, *)
public final class HTTPConnectionStateHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPRequestPart
    public typealias InboundOut = HTTPRequestPart
    public typealias OutboundIn = HTTPResponsePart
    public typealias OutboundOut = HTTPResponsePart

    let logger: Logger
    var state: StateMachine<ContinuousClock>
    private var scheduledReaderTask: Optional<Scheduled<Void>>

    public init(idleTimeout: Duration? = nil, logger: Logger) {
        self.logger = logger
        self.state = .init(idleTimeout: idleTimeout, clock: .init())
        self.scheduledReaderTask = nil
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive {
            switch self.state.setActive() {
            case .scheduleTimeout(let deadline):
                self.scheduleIdleTask(context, deadline: deadline)
            case .doNothing:
                break
            }
        }
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        cancelIdleTasks(context)
    }

    public func channelActive(context: ChannelHandlerContext) {
        switch self.state.setActive() {
        case .scheduleTimeout(let deadline):
            self.scheduleIdleTask(context, deadline: deadline)
        case .doNothing:
            break
        }
        context.fireChannelActive()
    }

    public func channelInactive(context: ChannelHandlerContext) {
        self.state.setInactive()
    }
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        self.state.readHTTPPart(part)
        context.fireChannelRead(data)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        switch self.state.writeHTTPPart(part) {
        case .scheduleTimeout(let deadline):
            self.scheduleIdleTask(context, deadline: deadline)
            context.write(data, promise: promise)
        case .closeConnection:
            context.writeAndFlush(data, promise: promise)
            context.close(promise: nil)
        case .doNothing:
            context.write(data, promise: promise)
        }
    }

    private func makeIdleTimeoutTask(_ context: ChannelHandlerContext) -> (() -> Void) {
        {
            self.scheduledReaderTask = nil
            switch self.state.timeoutTriggered() {
            case .rescheduleTimeout(let deadline):
                self.scheduleIdleTask(context, deadline: deadline)
            case .closeConnection:
                context.close(promise: nil)
            case .doNothing:
                break
            }
        }
    }

    private func scheduleIdleTask(
        _ context: ChannelHandlerContext,
        deadline: ContinuousClock.Instant
    ) {
        if self.scheduledReaderTask == nil {
            self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                in: .init(deadline - .now),
                makeIdleTimeoutTask(context)
            )
        }
    }

    private func cancelIdleTasks(_ context: ChannelHandlerContext) {
        scheduledReaderTask?.cancel()
        scheduledReaderTask = nil
    }

    public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ChannelShouldQuiesceEvent:
            switch self.state.receivingQuiesceEvent() {
            case .closeConnection:
                context.close(promise: nil)
            case .doNothing:
                break
            }

        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}

@available(hummingbird 2.0, *)
extension HTTPConnectionStateHandler {
    struct StateMachine<C: Clock> {
        let idleTimeout: C.Duration?
        let clock: C

        var requestsInProgress: Int = 0
        var isRequestBeingRead: Bool = false
        var lastActiveTime: C.Instant
        var isActive: Bool = false
        var closeAfterResponseWritten: Bool = false

        @inlinable
        init(idleTimeout: C.Duration?, clock: C) {
            self.clock = clock
            self.idleTimeout = idleTimeout
            self.lastActiveTime = clock.now
        }

        enum SetActiveAction: Equatable {
            case scheduleTimeout(deadline: C.Instant)
            case doNothing
        }

        @inlinable
        mutating func setActive() -> SetActiveAction {
            self.isActive = true
            if let idleTimeout {
                return .scheduleTimeout(deadline: clock.now.advanced(by: idleTimeout))
            } else {
                return .doNothing
            }
        }

        @inlinable
        mutating func setInactive() {
            self.isActive = false
        }

        @inlinable
        mutating func readHTTPPart(_ part: HTTPRequestPart) {
            self.lastActiveTime = clock.now
            switch part {
            case .head:
                self.isRequestBeingRead = true
                self.requestsInProgress += 1
            case .body(_):
                break
            case .end:
                self.isRequestBeingRead = false
            }
        }

        enum WritePartAction: Equatable {
            case scheduleTimeout(deadline: C.Instant)
            case closeConnection
            case doNothing
        }

        @inlinable
        mutating func writeHTTPPart(_ part: HTTPResponsePart) -> WritePartAction {
            switch part {
            case .head:
                break
            case .body(_):
                break
            case .end:
                self.requestsInProgress -= 1
                if self.requestsInProgress == 0 {
                    if self.closeAfterResponseWritten {
                        return .closeConnection
                    }
                    if let idleTimeout, self.isActive {
                        self.lastActiveTime = clock.now
                        return .scheduleTimeout(deadline: clock.now.advanced(by: idleTimeout))
                    }
                }
            }
            return .doNothing
        }

        enum TimeoutTriggeredAction: Equatable {
            case closeConnection
            case rescheduleTimeout(deadline: C.Instant)
            case doNothing
        }

        @inlinable
        mutating func timeoutTriggered() -> TimeoutTriggeredAction {
            guard let idleTimeout, self.isActive else { return .doNothing }

            // if we've read the request and are still responding do nothing
            if self.isRequestBeingRead == false, self.requestsInProgress > 0 {
                return .doNothing
            }

            if clock.now >= self.lastActiveTime.advanced(by: idleTimeout) {
                return .closeConnection
            }
            return .rescheduleTimeout(deadline: self.lastActiveTime.advanced(by: idleTimeout))
        }

        enum ReceivedQuiesceAction: Equatable {
            case closeConnection
            case doNothing
        }

        @inlinable
        mutating func receivingQuiesceEvent() -> ReceivedQuiesceAction {
            // we received a quiesce event. If we have any requests in progress we should
            // wait for them to finish
            if self.requestsInProgress > 0 {
                self.closeAfterResponseWritten = true
                return .doNothing
            } else {
                return .closeConnection
            }
        }
    }
}

@available(*, unavailable)
extension HTTPConnectionStateHandler: Sendable {}
