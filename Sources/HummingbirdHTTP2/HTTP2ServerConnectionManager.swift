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

final class HTTP2ServerConnectionManager: ChannelDuplexHandler {
    package typealias InboundIn = HTTP2Frame
    package typealias InboundOut = HTTP2Frame
    package typealias OutboundIn = HTTP2Frame
    package typealias OutboundOut = HTTP2Frame

    /// EventLoop connection manager running on
    let eventLoop: EventLoop
    /// HTTP2ServerConnectionManager state
    var state: StateMachine

    init(eventLoop: EventLoop) {
        self.eventLoop = eventLoop
        self.state = .init()
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
    }

    /// An HTTP/2 stream with the given ID was closed.
    func _streamClosed(_ id: HTTP2StreamID, channel: Channel) {
        self.state.streamClosed(id, channel: channel)
    }
}

extension HTTP2ServerConnectionManager {
    struct StateMachine {
        var state: State

        init() {
            self.state = .active(.init(openStreams: [:]))
        }

        enum State {
            struct ActiveState {
                var openStreams: [HTTP2StreamID: Channel]
            }

            struct ClosingState {
                var openStreams: [HTTP2StreamID: Channel]
            }

            case active(ActiveState)
            case closing(ClosingState)
            case closed
        }

        mutating func streamOpened(_ id: HTTP2StreamID, channel: Channel) {
            switch self.state {
            case .active(var activeState):
                activeState.openStreams[id] = channel
                self.state = .active(activeState)

            case .closing(var closingState):
                closingState.openStreams[id] = channel
                self.state = .closing(closingState)

            case .closed:
                break
            }
        }

        mutating func streamClosed(_ id: HTTP2StreamID, channel: Channel) {
            switch self.state {
            case .active(var activeState):
                activeState.openStreams[id] = nil
                self.state = .active(activeState)

            case .closing(var closingState):
                closingState.openStreams[id] = nil
                self.state = .closing(closingState)

            case .closed:
                break
            }
        }
    }
}
