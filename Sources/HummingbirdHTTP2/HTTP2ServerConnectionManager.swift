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
import NIOHTTP2

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
    /// EventLoop connection manager running on
    var eventLoop: EventLoop
    /// Channel handler context
    var channelHandlerContext: ChannelHandlerContext?

    init(eventLoop: EventLoop, idleTimeout: TimeAmount?) {
        self.eventLoop = eventLoop
        self.state = .init()
        self.idleTimer = idleTimeout.map { Timer(delay: $0) }
    }

    func channelActive(context: ChannelHandlerContext) {
        self.channelHandlerContext = context
        let loopBoundHandler = LoopBoundHandler(self)
        self.idleTimer?.schedule(on: self.eventLoop) {
            loopBoundHandler.triggerGracefulShutdown()
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        self.channelHandlerContext = nil
        self.idleTimer?.cancel()
    }

    func triggerGracefulShutdown(context: ChannelHandlerContext) {
        // This is not graceful at the moment
        context.close(mode: .all, promise: nil)
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
                self.handler._streamCreated(id, channel: channel)
            } else {
                self.handler.eventLoop.execute {
                    self.handler._streamCreated(id, channel: channel)
                }
            }
        }
    }

    var streamDelegate: HTTP2StreamDelegate {
        .init(handler: self)
    }

    /// A new HTTP/2 stream was created with the given ID.
    func _streamCreated(_ id: HTTP2StreamID, channel: Channel) {
        self.state.streamOpened(id, channel: channel)
        self.idleTimer?.cancel()
    }

    /// An HTTP/2 stream with the given ID was closed.
    func _streamClosed(_ id: HTTP2StreamID, channel: Channel) {
        switch self.state.streamClosed(id, channel: channel) {
        case .stateIdleTimer:
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
