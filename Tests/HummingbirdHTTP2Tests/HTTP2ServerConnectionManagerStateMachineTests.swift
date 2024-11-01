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

@testable import HummingbirdHTTP2
import NIOCore
import NIOHTTP2
import XCTest

final class HTTP2ServerConnectionManagerStateMachineTests: XCTestCase {
    func testAddRemoveClose() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(2))
        XCTAssertEqual(stateMachine.streamClosed(.init(2)), .startIdleTimer)
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else { XCTFail(); return }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else { XCTFail(); return }
        XCTAssertEqual(close, true)
        XCTAssertEqual(lastStreamId, 2)
        guard case .closed = stateMachine.state else { XCTFail(); return }
    }

    func testAddCloseRemove() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(2))
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else { XCTFail(); return }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else { XCTFail(); return }
        XCTAssertEqual(close, false)
        XCTAssertEqual(lastStreamId, 2)
        XCTAssertEqual(stateMachine.streamClosed(.init(2)), .close)
        guard case .closed = stateMachine.state else { XCTFail(); return }
    }

    func testCloseAddRemove() {
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else { XCTFail(); return }
        stateMachine.streamOpened(.init(2))
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(let lastStreamId, let close) = pingAckResult else { XCTFail(); return }
        XCTAssertEqual(close, false)
        XCTAssertEqual(lastStreamId, 2)
        XCTAssertEqual(stateMachine.streamClosed(.init(2)), .close)
        guard case .closed = stateMachine.state else { XCTFail(); return }
    }

    func testReceivedPing() {
        let now = NIODeadline.now()
        let pingData = HTTP2PingData(withInteger: .random(in: .min ... .max))
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        stateMachine.streamOpened(.init(4))
        var pingResult = stateMachine.receivedPing(atTime: now, data: pingData)
        guard case .sendPingAck(let data) = pingResult else { XCTFail(); return }
        XCTAssertEqual(data, pingData)
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(1), data: pingData)
        guard case .sendPingAck = pingResult else { XCTFail(); return }
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(1), data: pingData)
        guard case .sendPingAck = pingResult else { XCTFail(); return }
        pingResult = stateMachine.receivedPing(atTime: now + .seconds(2), data: pingData)
        guard case .enhanceYouCalmAndClose(let id) = pingResult else { XCTFail(); return }
        XCTAssertEqual(id, 4)
        guard case .closed = stateMachine.state else { XCTFail(); return }
    }

    func testClosedState() {
        // get statemachine into closed state
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else { XCTFail(); return }
        let pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway(_, let close) = pingAckResult else { XCTFail(); return }
        XCTAssertEqual(close, true)

        // test closed state responses
        XCTAssertEqual(stateMachine.streamClosed(.init(0)), .none)
        guard case .none = stateMachine.receivedPing(atTime: .now(), data: .init()) else { XCTFail(); return }
        guard case .none = stateMachine.receivedPingAck(data: .init()) else { XCTFail(); return }
        guard case .none = stateMachine.triggerGracefulShutdown() else { XCTFail(); return }
    }

    func testClosePingAckWrongData() {
        let randomPingData = HTTP2PingData(withInteger: .random(in: .min ... .max))
        // get statemachine into closed state
        var stateMachine = HTTP2ServerConnectionManager.StateMachine()
        let triggerGracefulShutdownResult = stateMachine.triggerGracefulShutdown()
        guard case .sendGoAway(let pingData) = triggerGracefulShutdownResult else { XCTFail(); return }
        var pingAckResult = stateMachine.receivedPingAck(data: randomPingData)
        guard case .none = pingAckResult else { XCTFail(); return }
        pingAckResult = stateMachine.receivedPingAck(data: pingData)
        guard case .sendGoAway = pingAckResult else { XCTFail(); return }
    }
}
