//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import NIOCore
import NIOHTTPTypes
import Testing

@testable import HummingbirdCore

struct HTTPConnectionStateHandlerStateMachineTests {
    /// Should close connection if idle timer triggers and no head read
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutAfterActive() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        clock.advance(to: .init(.seconds(30)))
        let timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }

    /// Should close connection if idle timer triggers and only head read
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutAfterHeadRead() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        clock.advance(to: .init(.seconds(2)))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        clock.advance(to: .init(.seconds(30)))
        var timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .rescheduleTimeout(deadline: .init(.seconds(32))))
        clock.advance(to: .init(.seconds(32)))
        timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }

    /// Should close connection if idle timer triggers and head and some body read
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutAfterHeadReadBodyReading() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        clock.advance(to: .init(.seconds(2)))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        clock.advance(to: .init(.seconds(30)))
        var timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .rescheduleTimeout(deadline: .init(.seconds(32))))
        clock.advance(to: .init(.seconds(32)))
        timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }

    /// Should do nothing if idle timer triggers and request read
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func noIdleTimeoutAfterRequestRead() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        stateMachine.readHTTPPart(.end(nil))
        clock.advance(to: .init(.seconds(30)))
        let timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .doNothing)
    }

    /// Should do nothing if idle timer triggers and request read and response is being written
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func noIdleTimeoutAfterRequestReadResponseWriting() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        stateMachine.readHTTPPart(.end(nil))
        let writePartAction = stateMachine.writeHTTPPart(.head(.init(status: .ok)))
        #expect(writePartAction == .doNothing)
        clock.advance(to: .init(.seconds(30)))
        let timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .doNothing)
    }

    /// Should close connection if idle timer triggers and request is in progress of being read even though
    /// we have started writing a response
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutRequestReadingResponseWriting() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        clock.advance(to: .init(.seconds(2)))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        let writePartAction = stateMachine.writeHTTPPart(.head(.init(status: .ok)))
        #expect(writePartAction == .doNothing)
        clock.advance(to: .init(.seconds(30)))
        var timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .rescheduleTimeout(deadline: .init(.seconds(32))))
        clock.advance(to: .init(.seconds(32)))
        timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }

    /// Should close connection if idle timer triggers and request is still reading and response has been written
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutAfterRequestReadResponseWritten() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        stateMachine.readHTTPPart(.end(nil))
        clock.advance(to: .init(.seconds(2)))
        var writePartAction = stateMachine.writeHTTPPart(.head(.init(status: .ok)))
        #expect(writePartAction == .doNothing)
        writePartAction = stateMachine.writeHTTPPart(.end(nil))
        #expect(writePartAction == .scheduleTimeout(deadline: .init(.seconds(32))))
        clock.advance(to: .init(.seconds(32)))
        let timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test
    func idleTimeoutAfterRequestReadingResponseWritten() async throws {
        let clock = MockClock()
        var stateMachine = HTTPConnectionStateHandler.StateMachine(idleTimeout: .seconds(30), clock: clock)
        let activeAction = stateMachine.setActive()
        #expect(activeAction == .scheduleTimeout(deadline: MockClock.Instant(.seconds(30))))
        stateMachine.readHTTPPart(.head(.init(method: .get, scheme: "http", authority: "127.0.0.1", path: "/")))
        stateMachine.readHTTPPart(.body(.init()))
        clock.advance(to: .init(.seconds(2)))
        var writePartAction = stateMachine.writeHTTPPart(.head(.init(status: .ok)))
        #expect(writePartAction == .doNothing)
        writePartAction = stateMachine.writeHTTPPart(.end(nil))
        #expect(writePartAction == .scheduleTimeout(deadline: .init(.seconds(32))))
        clock.advance(to: .init(.seconds(32)))
        let timeoutAction = stateMachine.timeoutTriggered()
        #expect(timeoutAction == .closeConnection)
    }
}
