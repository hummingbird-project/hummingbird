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

/// Configuration for minimum request body read rate calculation
///
/// This defines how the ``HTTPConnectionStateHandler`` calculates whether the request body
/// is being read from the connection fast enough. If it considers the request body is coming in
/// too slow then it will close the connection.
///
/// Slowloris is a type of denial of service attack which uses minimal bandwidth. An attacker
/// will open as many connections to the server as possible and try to hold them open for as
/// long as possible. The idle connection timeout will close idle connections but it cannot catch
/// the situation where the attacker drip feeds bytes to the connection every so often. The
/// ``RequestBodyMinimumReadRateConfiguration`` is used to avoid these kind of attacks.
///
/// Note: Because back pressure is applied when you don't read the request body fast enough this
/// will also kick in if you don't read the request body.
@available(hummingbird 2.0, *)
public struct RequestBodyMinimumReadRateConfiguration: Sendable {
    /// minimum bytes read per second
    public var minimumBytesPerSecond: Double
    /// minimum time period before calculating rate
    public var minimumDuration: Duration
    /// How long before reseting calculation
    public var resetDuration: Duration

    public init(minimumBytesPerSecond: Double = 1024, minimumDuration: Duration = .seconds(5), resetDuration: Duration = .seconds(30)) {
        guard minimumDuration < resetDuration else {
            fatalError("Minimum duration needs to be lower than reset duration otherwise calculation is never performed")
        }
        self.minimumBytesPerSecond = minimumBytesPerSecond
        self.minimumDuration = minimumDuration
        self.resetDuration = resetDuration
    }
}

/// Manage HTTP connection
///
/// Checks for idle HTTP connections, slow connections and quiesce events from the server.
///
/// - A connection is considered idle if we receive no incoming HTTP parts for a defined
/// time out period when the connection is either in the middle of reading a request or not
/// writing a response.
/// - A connection is consider slow during reading the request body if the rate of bytes read
/// goes below a certain amount.
///
/// Idle and slow connections are closed
@available(hummingbird 2.0, *)
public final class HTTPConnectionStateHandler: ChannelDuplexHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPRequestPart
    public typealias InboundOut = HTTPRequestPart
    public typealias OutboundIn = HTTPResponsePart
    public typealias OutboundOut = HTTPResponsePart

    let logger: Logger
    var state: StateMachine<ContinuousClock>
    private var scheduledReaderTask: Optional<Scheduled<Void>>

    public init(idleTimeout: Duration? = nil, requestBodyMinimumReadRate: RequestBodyMinimumReadRateConfiguration? = nil, logger: Logger) {
        self.logger = logger
        self.state = .init(idleTimeout: idleTimeout, requestBodyMinimumReadRate: requestBodyMinimumReadRate, clock: .init())
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
        switch self.state.readHTTPPart(part) {
        case .closeConnection:
            context.close(promise: nil)
            return
        case .doNothing:
            break
        }
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
    struct StateMachine<C: Clock> where C.Duration == Duration {
        let idleTimeout: Duration?
        let requestBodyMinimumReadRate: RequestBodyMinimumReadRateConfiguration?
        let clock: C

        var requestsInProgress: Int = 0
        var isRequestBeingRead: Bool = false
        var lastActiveTime: C.Instant
        var bodyRateBaseTime: C.Instant
        var isActive: Bool = false
        var closeAfterResponseWritten: Bool = false
        var bodyRead: Int

        @inlinable
        init(idleTimeout: Duration?, requestBodyMinimumReadRate: RequestBodyMinimumReadRateConfiguration? = nil, clock: C) {
            self.clock = clock
            self.idleTimeout = idleTimeout
            self.lastActiveTime = clock.now
            self.bodyRateBaseTime = self.lastActiveTime
            self.requestBodyMinimumReadRate = requestBodyMinimumReadRate
            self.bodyRead = 0
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

        enum ReadHTTPPartAction {
            case closeConnection
            case doNothing
        }

        @inlinable
        mutating func readHTTPPart(_ part: HTTPRequestPart) -> ReadHTTPPartAction {
            switch part {
            case .head:
                self.isRequestBeingRead = true
                self.requestsInProgress += 1
                self.bodyRateBaseTime = clock.now
            case .body(let buffer):
                if let requestBodyMinimumReadRate {
                    self.bodyRead += buffer.readableBytes
                    let duration = self.bodyRateBaseTime.duration(to: clock.now)
                    guard duration >= requestBodyMinimumReadRate.minimumDuration else {
                        break
                    }
                    let rate = Double(self.bodyRead) / duration.timeInterval
                    if rate < requestBodyMinimumReadRate.minimumBytesPerSecond {
                        return .closeConnection
                    }
                    if duration > requestBodyMinimumReadRate.resetDuration {
                        self.self.bodyRateBaseTime = clock.now
                        self.bodyRead = 0
                    }
                }
            case .end:
                self.isRequestBeingRead = false
            }
            self.lastActiveTime = clock.now
            return .doNothing
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

@available(hummingbird 2.0, *)
extension Duration {
    // Duration in seconds as a double
    var timeInterval: Double {
        let v = components
        return Double(v.seconds) + Double(v.attoseconds) * 1e-18
    }
}
