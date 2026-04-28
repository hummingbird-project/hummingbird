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
@available(hummingbird 2.0, *)
public final class HTTPConnectionStateHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPRequestPart
    public typealias InboundOut = HTTPRequestPart
    public typealias OutboundIn = HTTPResponsePart
    public typealias OutboundOut = HTTPResponsePart

    ///A user event triggered by IdleStateHandler when a Channel is idle.
    public enum IdleStateEvent: Sendable {
        /// Will be triggered when no read was performed for the specified amount of time
        case read
    }

    public let readIdleTimeout: TimeAmount?
    public let readBodyRateRequirement: (start: TimeAmount, rate: Double)?

    private var startedReadingBody: NIODeadline = .distantPast
    private var bodyReadAmount: Int = 0
    private var lastActiveTime: NIODeadline = .distantPast
    private var scheduledReaderTask: Optional<Scheduled<Void>>

    public init(idleTimeout: TimeAmount? = nil, readBodyRateRequirement: (start: TimeAmount, rate: Double)? = nil) {
        self.readIdleTimeout = idleTimeout
        self.readBodyRateRequirement = readBodyRateRequirement
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
        let part = unwrapInboundIn(data)
        switch part {
        case .head:
            self.startedReadingBody = .now()
            self.bodyReadAmount = 0
        case .body(let buffer):
            if let readBodyRateRequirement {
                self.bodyReadAmount += buffer.readableBytes
                let timeSinceStartingToReadBody = NIODeadline.now() - self.startedReadingBody
                if timeSinceStartingToReadBody > readBodyRateRequirement.start {

                }
            }
        case .end:
            break
        }
        self.lastActiveTime = .now()
        context.fireChannelRead(data)
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = unwrapOutboundIn(data)
        switch part {
        case .head:
            break
        case .body:
            break
        case .end:
            break
        }

        self.lastActiveTime = .now()
        context.write(data, promise: promise)
    }

    private func shouldReschedule(_ context: ChannelHandlerContext) -> Bool {
        context.channel.isActive
    }

    private func makeIdleTimeoutTask(_ context: ChannelHandlerContext, _ timeout: TimeAmount) -> (() -> Void) {
        {
            guard self.shouldReschedule(context) else {
                return
            }
            let diff = .now() - self.lastActiveTime
            if diff >= timeout {
                // Reader is idle - set a new timeout and trigger an event through the pipeline
                self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                    in: timeout,
                    self.makeIdleTimeoutTask(context, timeout)
                )

                context.fireUserInboundEventTriggered(IdleStateEvent.read)
            } else {
                // Read occurred before the timeout - set a new timeout with shorter delay.
                self.scheduledReaderTask = context.eventLoop.assumeIsolatedUnsafeUnchecked().scheduleTask(
                    deadline: self.lastActiveTime + timeout,
                    self.makeIdleTimeoutTask(context, timeout)
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
        lastActiveTime = now
        scheduledReaderTask = schedule(context, readIdleTimeout, makeIdleTimeoutTask)
    }

    private func cancelIdleTasks(_ context: ChannelHandlerContext) {
        scheduledReaderTask?.cancel()
        scheduledReaderTask = nil
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
                if self.requestsInProgress == 0, let idleTimeout, self.isActive {
                    self.lastActiveTime = clock.now
                    return .scheduleTimeout(deadline: clock.now.advanced(by: idleTimeout))
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

            if self.isRequestBeingRead == false, self.requestsInProgress > 0 {
                return .doNothing
            }

            if clock.now >= self.lastActiveTime.advanced(by: idleTimeout) {
                return .closeConnection
            }
            return .rescheduleTimeout(deadline: self.lastActiveTime.advanced(by: idleTimeout))
        }
    }
}

@available(*, unavailable)
extension HTTPConnectionStateHandler: Sendable {}
