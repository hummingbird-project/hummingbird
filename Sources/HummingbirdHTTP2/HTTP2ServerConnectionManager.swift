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

import NIOCore
import NIOHTTP2

/// HTTP2 server connection manager
///
/// This is heavily based off the ServerConnectionManagementHandler from https://github.com/grpc/grpc-swift-nio-transport
final class HTTP2ServerConnectionManager: ChannelDuplexHandler {
    package typealias InboundIn = HTTP2Frame
    package typealias InboundOut = HTTP2Frame
    package typealias OutboundIn = HTTP2Frame
    package typealias OutboundOut = HTTP2Frame

    /// HTTP2ServerConnectionManager state
    var state: StateMachine
    /// Idle timer
    var idleTimer: Timer?
    /// Maximum time a connection be open timer
    var maxAgeTimer: Timer?
    /// Maximum amount of time we wait before closing the connection
    var gracefulCloseTimer: Timer?
    /// EventLoop connection manager running on
    var eventLoop: EventLoop
    /// Channel handler context
    var channelHandlerContext: ChannelHandlerContext?
    /// Are we reading
    var inReadLoop: Bool
    /// flush pending when read completes
    var flushPending: Bool

    init(
        eventLoop: EventLoop,
        idleTimeout: Duration?,
        maxAgeTimeout: Duration?,
        gracefulCloseTimeout: Duration?
    ) {
        self.eventLoop = eventLoop
        self.state = .init()
        self.inReadLoop = false
        self.flushPending = false
        self.idleTimer = idleTimeout.map { Timer(delay: .init($0)) }
        self.maxAgeTimer = maxAgeTimeout.map { Timer(delay: .init($0)) }
        self.gracefulCloseTimer = gracefulCloseTimeout.map { Timer(delay: .init($0)) }
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.channelHandlerContext = context
        let loopBoundHandler = LoopBoundHandler(self)
        self.idleTimer?.schedule(on: self.eventLoop) {
            loopBoundHandler.triggerGracefulShutdown()
        }
        self.maxAgeTimer?.schedule(on: self.eventLoop) {
            loopBoundHandler.triggerGracefulShutdown()
        }
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.idleTimer?.cancel()
        self.gracefulCloseTimer?.cancel()
        self.channelHandlerContext = nil
    }

    func channelActive(context: ChannelHandlerContext) {
        context.fireChannelActive()
    }

    func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.inReadLoop = true

        let frame = self.unwrapInboundIn(data)
        switch frame.payload {
        case .ping(let data, let ack):
            if ack {
                self.handlePingAck(context: context, data: data)
            } else {
                self.handlePing(context: context, data: data)
            }

        default:
            break // Only interested in PING frames, ignore the rest.
        }

        context.fireChannelRead(data)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        self.inReadLoop = false
        if self.flushPending {
            context.flush()
            self.flushPending = false
        }
        context.fireChannelReadComplete()
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case is ChannelShouldQuiesceEvent:
            self.triggerGracefulShutdown(context: context)
        case let channelEvent as ChannelEvent where channelEvent == .inputClosed:
            self.handleInputClosed(context: context)
        default:
            break
        }
        context.fireUserInboundEventTriggered(event)
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        context.close(mode: .all, promise: nil)
    }

    func optionallyFlush(context: ChannelHandlerContext) {
        if self.inReadLoop {
            self.flushPending = true
        } else {
            context.flush()
        }
    }

    func handlePing(context: ChannelHandlerContext, data: HTTP2PingData) {
        switch self.state.receivedPing(atTime: .now(), data: data) {
        case .sendPingAck:
            break // ping acks are sent by NIOHTTP2 channel handler

        case .enhanceYourCalmAndClose(let lastStreamId):
            let goAway = HTTP2Frame(
                streamID: .rootStream,
                payload: .goAway(
                    lastStreamID: lastStreamId,
                    errorCode: .enhanceYourCalm,
                    opaqueData: context.channel.allocator.buffer(string: "too_many_pings")
                )
            )

            context.write(self.wrapOutboundOut(goAway), promise: nil)
            self.optionallyFlush(context: context)
            context.close(promise: nil)

        case .none:
            break
        }
    }

    func handlePingAck(context: ChannelHandlerContext, data: HTTP2PingData) {
        switch self.state.receivedPingAck(data: data) {
        case .sendGoAway(let lastStreamId, let close):
            let goAway = HTTP2Frame(
                streamID: .rootStream,
                payload: .goAway(
                    lastStreamID: lastStreamId,
                    errorCode: .noError,
                    opaqueData: nil
                )
            )
            context.write(self.wrapOutboundOut(goAway), promise: nil)
            self.optionallyFlush(context: context)

            if close {
                context.close(promise: nil)
            } else {
                // Setup grace period for closing. Close the connection abruptly once the grace period passes.
                let loopBound = NIOLoopBound(context, eventLoop: context.eventLoop)
                self.gracefulCloseTimer?.schedule(on: context.eventLoop) {
                    loopBound.value.close(promise: nil)
                }
            }
        case .none:
            break
        }
    }

    func triggerGracefulShutdown(context: ChannelHandlerContext) {
        switch self.state.triggerGracefulShutdown() {
        case .sendGoAway(let pingData):
            let goAway = HTTP2Frame(
                streamID: .rootStream,
                payload: .goAway(
                    lastStreamID: .maxID,
                    errorCode: .noError,
                    opaqueData: nil
                )
            )
            let ping = HTTP2Frame(streamID: .rootStream, payload: .ping(pingData, ack: false))
            context.write(self.wrapOutboundOut(goAway), promise: nil)
            context.write(self.wrapOutboundOut(ping), promise: nil)
            self.optionallyFlush(context: context)

        case .none:
            break
        }
    }

    func handleInputClosed(context: ChannelHandlerContext) {
        switch self.state.inputClosed() {
        case .closeWithGoAway(let lastStreamId):
            let goAway = HTTP2Frame(
                streamID: .rootStream,
                payload: .goAway(
                    lastStreamID: lastStreamId,
                    errorCode: .connectError,
                    opaqueData: context.channel.allocator.buffer(string: "input_closed")
                )
            )

            context.write(self.wrapOutboundOut(goAway), promise: nil)
            self.optionallyFlush(context: context)
            context.close(promise: nil)

        case .close:
            context.close(promise: nil)

        case .none:
            break
        }
    }
}

extension HTTP2ServerConnectionManager {
    struct LoopBoundHandler: @unchecked Sendable {
        let handler: HTTP2ServerConnectionManager
        init(_ handler: HTTP2ServerConnectionManager) {
            self.handler = handler
        }

        func triggerGracefulShutdown() {
            self.handler.eventLoop.preconditionInEventLoop()
            guard let context = self.handler.channelHandlerContext else { return }
            self.handler.triggerGracefulShutdown(context: context)
        }
    }
}

extension HTTP2ServerConnectionManager {
    /// Stream delegate
    struct HTTP2StreamDelegate: NIOHTTP2StreamDelegate, @unchecked Sendable {
        let handler: HTTP2ServerConnectionManager

        /// A new HTTP/2 stream was created with the given ID.
        func streamCreated(_ id: HTTP2StreamID, channel: Channel) {
            if self.handler.eventLoop.inEventLoop {
                self.handler._streamCreated(id, channel: channel)
            } else {
                self.handler.eventLoop.execute {
                    self.handler._streamCreated(id, channel: channel)
                }
            }
        }

        /// An HTTP/2 stream with the given ID was closed.
        func streamClosed(_ id: HTTP2StreamID, channel: Channel) {
            if self.handler.eventLoop.inEventLoop {
                self.handler._streamClosed(id, channel: channel)
            } else {
                self.handler.eventLoop.execute {
                    self.handler._streamClosed(id, channel: channel)
                }
            }
        }
    }

    var streamDelegate: HTTP2StreamDelegate {
        .init(handler: self)
    }

    /// A new HTTP/2 stream was created with the given ID.
    func _streamCreated(_ id: HTTP2StreamID, channel: Channel) {
        self.state.streamOpened(id)
        self.idleTimer?.cancel()
    }

    /// An HTTP/2 stream with the given ID was closed.
    func _streamClosed(_ id: HTTP2StreamID, channel: Channel) {
        switch self.state.streamClosed(id) {
        case .startIdleTimer:
            let loopBoundHandler = LoopBoundHandler(self)
            self.idleTimer?.schedule(on: self.eventLoop) {
                loopBoundHandler.triggerGracefulShutdown()
            }
        case .close:
            LoopBoundHandler(self).triggerGracefulShutdown()
        case .none:
            break
        }
    }
}

struct Timer {
    var scheduled: Scheduled<Void>?
    let delay: TimeAmount

    init(delay: TimeAmount) {
        self.delay = delay
        self.scheduled = nil
    }

    mutating func schedule(on eventLoop: EventLoop, _ task: @escaping @Sendable () throws -> Void) {
        self.cancel()
        self.scheduled = eventLoop.scheduleTask(in: self.delay, task)
    }

    mutating func cancel() {
        self.scheduled?.cancel()
        self.scheduled = nil
    }
}
