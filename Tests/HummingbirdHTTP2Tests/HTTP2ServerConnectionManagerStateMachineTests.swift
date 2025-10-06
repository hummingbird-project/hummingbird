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
import Testing

@testable import HummingbirdHTTP2

struct HTTP2ServerConnectionManagerStateMachineTests {
    @Test func testAddRemoveClose() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(2))
        #expect(stateMachine.streamClosed(.init(2)) == .startIdleTimer)
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else {
            Issue.record()
            return
        }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else {
            Issue.record()
            return
        }
        #expect(close == true)
        #expect(lastStreamId == 2)
        let isClosed = stateMachine.isClosed()
        #expect(isClosed)
    }

    @Test func testAddCloseRemove() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(2))
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else {
            Issue.record()
            return
        }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else {
            Issue.record()
            return
        }
        #expect(close == false)
        #expect(lastStreamId == 2)
        #expect(stateMachine.streamClosed(.init(2)) == .close)
        let isClosed = stateMachine.isClosed()
        #expect(isClosed)
    }

    @Test func testCloseAddRemove() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else {
            Issue.record()
            return
        }
        stateMachine.streamOpened(.init(2))
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else {
            Issue.record()
            return
        }
        #expect(close == false)
        #expect(lastStreamId == 2)
        #expect(stateMachine.streamClosed(.init(2)) == .close)
        let isClosed = stateMachine.isClosed()
        #expect(isClosed)
    }

    @Test func testReceivedPing() {
        let now = NIODeadline.now()
        let pingData = HTTP2PingData(withInteger: .random(in: .min ... .max))
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(4))
        var pingResult = stateMachine.receivedPing(atTime: now, data: pingData)
        guard case .sendPingAck(let data) = pingResult else {
            Issue.record()
            return
        }
        #expect(data == pingData)
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(1), data: pingData)
        guard case .sendPingAck = pingResult else {
            Issue.record()
            return
        }
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(1), data: pingData)
        guard case .sendPingAck = pingResult else {
            Issue.record()
            return
        }
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(2), data: pingData)
        guard case .enhanceYourCalmAndClose(let id) = pingResult else {
            Issue.record()
            return
        }
        #expect(id == 4)
        let isClosed = stateMachine.isClosed()
        #expect(isClosed)
    }

    @Test func testClosedState() {
        // get statemachine into closed state
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else {
            Issue.record()
            return
        }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(_, let close) = pingAckResult else {
            Issue.record()
            return
        }
        #expect(close == true)

        // test closed state responses
        #expect(stateMachine.streamClosed(.init(0)) == .none)
        guard case .none = stateMachine.receivedPing(atTime: .now(), data: .init()) else {
            Issue.record()
            return
        }
        guard case .none = stateMachine.receivedPingAck(data: .init()) else {
            Issue.record()
            return
        }
        guard case .none = stateMachine.triggerGracefulShutdown() else {
            Issue.record()
            return
        }
    }

    @Test func testClosePingAckWrongData() {
        let randomPingData = HTTP2PingData(withInteger: .random(in: .min ... .max))
        // get statemachine into closed state
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else {
            Issue.record()
            return
        }
        var pingAckResult = stateMachine.receivedPingAck(data: randomPingData)
        guard case .none = pingAckResult else {
            Issue.record()
            return
        }
        pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway = pingAckResult else {
            Issue.record()
            return
        }
    }
}
