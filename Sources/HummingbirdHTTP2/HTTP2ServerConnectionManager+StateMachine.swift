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

extension HTTP2ServerConnectionManager {
    struct StateMachine {
        var state: State

        init() {
            self.state = .active(.init())
        }

        mutating func streamOpened(_ id: HTTP2StreamID, channel: Channel) {
            switch self.state {
            case .active(var activeState):
                activeState.openStreams[id] = channel
                activeState.lastStreamId = id
                self.state = .active(activeState)

            case .closing(var closingState):
                closingState.openStreams[id] = channel
                closingState.lastStreamId = id
                self.state = .closing(closingState)

            case .closed:
                break
            }
        }

        enum ClosedResult {
            case stateIdleTimer
            case close
            case none
        }

        mutating func streamClosed(_ id: HTTP2StreamID, channel: Channel) -> ClosedResult {
            switch self.state {
            case .active(var activeState):
                activeState.openStreams[id] = nil
                self.state = .active(activeState)
                if activeState.openStreams.isEmpty {
                    return .stateIdleTimer
                } else {
                    return .none
                }

            case .closing(var closingState):
                closingState.openStreams[id] = nil
                self.state = .closing(closingState)
                if closingState.openStreams.isEmpty, closingState.sentSecondGoAway == true {
                    return .close
                } else {
                    return .none
                }

            case .closed:
                return .none
            }
        }

        enum StartGracefulShutdownResult {
            case sendGoAway(pingData: HTTP2PingData)
            case none
        }

        mutating func startGracefulShutdown() -> StartGracefulShutdownResult {
            switch self.state {
            case .active(let activeState):
                let closingState = State.ClosingState(from: activeState)
                self.state = .closing(closingState)
                return .sendGoAway(pingData: closingState.goAwayPingData)

            case .closing:
                return .none

            case .closed:
                return .none
            }
        }

        enum ReceivedPingResult {
            case sendPingAck(pingData: HTTP2PingData)
            case close(lastStreamId: HTTP2StreamID)
            case none
        }

        mutating func receivedPing(atTime time: NIODeadline, data: HTTP2PingData) -> ReceivedPingResult {
            switch self.state {
            case .active(var activeState):
                let tooManyPings = activeState.keepalive.receivedPing(atTime: time, hasOpenStreams: activeState.openStreams.count > 0)
                if tooManyPings {
                    self.state = .closed
                    return .close(lastStreamId: activeState.lastStreamId)
                } else {
                    self.state = .active(activeState)
                    return .sendPingAck(pingData: data)
                }

            case .closing(var closingState):
                let tooManyPings = closingState.keepalive.receivedPing(atTime: time, hasOpenStreams: closingState.openStreams.count > 0)
                if tooManyPings {
                    self.state = .closed
                    return .close(lastStreamId: closingState.lastStreamId)
                } else {
                    self.state = .closing(closingState)
                    return .sendPingAck(pingData: data)
                }

            case .closed:
                return .none
            }
        }

        enum ReceivedPingAckResult {
            case sendGoAway(lastStreamId: HTTP2StreamID, close: Bool)
            case none
        }

        mutating func receivedPingAck(data: HTTP2PingData) -> ReceivedPingAckResult {
            switch self.state {
            case .active:
                return .none

            case .closing(var state):
                guard state.goAwayPingData == data else {
                    return .none
                }
                state.sentSecondGoAway = true
                if state.openStreams.count > 0 {
                    self.state = .closing(state)
                    return .sendGoAway(lastStreamId: state.lastStreamId, close: false)
                } else {
                    self.state = .closed
                    return .sendGoAway(lastStreamId: state.lastStreamId, close: true)
                }

            case .closed:
                return .none
            }
        }
    }
}

extension HTTP2ServerConnectionManager.StateMachine {
    enum State {
        struct ActiveState {
            var openStreams: [HTTP2StreamID: Channel]
            var lastStreamId: HTTP2StreamID
            var keepalive: Keepalive

            init() {
                self.openStreams = [:]
                self.lastStreamId = .rootStream
                self.keepalive = .init(allowWithoutCalls: true, minPingReceiveIntervalWithoutCalls: .seconds(30))
            }
        }

        struct ClosingState {
            var openStreams: [HTTP2StreamID: Channel]
            var lastStreamId: HTTP2StreamID
            var keepalive: Keepalive
            var sentSecondGoAway: Bool
            let goAwayPingData: HTTP2PingData

            init(from activeState: ActiveState) {
                self.openStreams = activeState.openStreams
                self.lastStreamId = activeState.lastStreamId
                self.keepalive = activeState.keepalive
                self.sentSecondGoAway = false
                self.goAwayPingData = HTTP2PingData(withInteger: .random(in: .min ... .max))
            }
        }

        case active(ActiveState)
        case closing(ClosingState)
        case closed
    }
}

extension HTTP2ServerConnectionManager.StateMachine {
    struct Keepalive {
        /// Allow the client to send keep alive pings when there are no active calls.
        private let allowWithoutCalls: Bool

        /// The minimum time interval which pings may be received at when there are no active calls.
        private let minPingReceiveIntervalWithoutCalls: TimeAmount

        /// The maximum number of "bad" pings sent by the client the server tolerates before closing
        /// the connection.
        private let maxPingStrikes: Int

        /// The number of "bad" pings sent by the client. This can be reset when the server sends
        /// DATA or HEADERS frames.
        ///
        /// Ping strikes account for pings being occasionally being used for purposes other than keep
        /// alive (a low number of strikes is therefore expected and okay).
        private var pingStrikes: Int

        /// The last time a valid ping happened.
        ///
        /// Note: `distantPast` isn't used to indicate no previous valid ping as `NIODeadline` uses
        /// the monotonic clock on Linux which uses an undefined starting point and in some cases isn't
        /// always that distant.
        private var lastValidPingTime: NIODeadline?

        init(allowWithoutCalls: Bool, minPingReceiveIntervalWithoutCalls: TimeAmount) {
            self.allowWithoutCalls = allowWithoutCalls
            self.minPingReceiveIntervalWithoutCalls = minPingReceiveIntervalWithoutCalls
            self.maxPingStrikes = 2
            self.pingStrikes = 0
            self.lastValidPingTime = nil
        }

        /// Reset ping strikes and the time of the last valid ping.
        mutating func reset() {
            self.lastValidPingTime = nil
            self.pingStrikes = 0
        }

        /// Returns whether the client has sent too many pings.
        mutating func receivedPing(atTime time: NIODeadline, hasOpenStreams: Bool) -> Bool {
            let interval: TimeAmount

            if hasOpenStreams || self.allowWithoutCalls {
                interval = self.minPingReceiveIntervalWithoutCalls
            } else {
                // If there are no open streams and keep alive pings aren't allowed without calls then
                // use an interval of two hours.
                //
                // This comes from gRFC A8: https://github.com/grpc/proposal/blob/master/A8-client-side-keepalive.md
                interval = .hours(2)
            }

            // If there's no last ping time then the first is acceptable.
            let isAcceptablePing = self.lastValidPingTime.map { $0 + interval <= time } ?? true
            let tooManyPings: Bool

            if isAcceptablePing {
                self.lastValidPingTime = time
                tooManyPings = false
            } else {
                self.pingStrikes += 1
                tooManyPings = self.pingStrikes > self.maxPingStrikes
            }

            return tooManyPings
        }
    }
}
