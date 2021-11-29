//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
@testable import Hummingbird
import NIOPosix
import XCTest

final class ConnectionPoolTests: XCTestCase {
    final class Connection: HBConnection {
        static func make(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Connection> {
            return eventLoop.makeSucceededFuture(.init(eventLoop: eventLoop))
        }
        
        let eventLoop: EventLoop
        var isClosed: Bool
        
        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
            self.isClosed = false
        }

        func close(logger: Logger) -> EventLoopFuture<Void> {
            self.isClosed = true
            return eventLoop.makeSucceededVoidFuture()
        }
    }
    
    static var logger = Logger(label: "ConnectionPoolTests")
    static var eventLoopGroup: EventLoopGroup!
    
    static override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        logger.logLevel = .trace
    }
    
    static override func tearDown() {
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }
    
    func testRequestRelease() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<Connection>(maxConnections: 4, eventLoop: eventLoop)
        let c = try pool.request(logger: Self.logger).wait()
        pool.release(connection: c, logger: Self.logger)
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            XCTAssertEqual(pool.availableQueue.count, 1)
            return pool.close(logger: Self.logger)
        }.wait()
    }
    
    func testWaiting() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<Connection>(maxConnections: 1, eventLoop: eventLoop)
        let c = try pool.request(logger: Self.logger).wait()
        let c2Future = pool.request(logger: Self.logger)
        eventLoop.execute {
            XCTAssertEqual(pool.waitingQueue.count, 1)
            pool.release(connection: c, logger: Self.logger)
        }
        let c2 = try c2Future.wait()
        pool.release(connection: c2, logger: Self.logger)
        try pool.close(logger: Self.logger).wait()
    }
    
    func testMultiRequestRelease() throws {
        /// connection that keeps count of instance
        final class ConnectionCounter: HBConnection {
            static func make(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<ConnectionCounter> {
                return eventLoop.makeSucceededFuture(.init(eventLoop: eventLoop))
            }
            static var counter: Int = 0
            static var deletedCounter: Int = 0
            
            let eventLoop: EventLoop
            var isClosed: Bool
            
            init(eventLoop: EventLoop) {
                self.eventLoop = eventLoop
                self.isClosed = false
                Self.counter += 1
            }
            
            deinit {
                Self.deletedCounter += 1
            }

            func close(logger: Logger) -> EventLoopFuture<Void> {
                self.isClosed = true
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<ConnectionCounter>(maxConnections: 4, eventLoop: eventLoop)
        let futures: [EventLoopFuture<Void>] = (0..<100).map { _ -> EventLoopFuture<Void> in
            let task = Self.eventLoopGroup.next().flatScheduleTask(in: .microseconds(Int64.random(in: 0..<5000))) { () -> EventLoopFuture<Void> in
                pool.request(logger: Self.logger).flatMap { connection -> EventLoopFuture<Void> in
                    Self.eventLoopGroup.next().scheduleTask(in: .microseconds(Int64.random(in: 0..<5000))) {
                        pool.release(connection: connection, logger: Self.logger)
                    }.futureResult
                }
            }
            return task.futureResult
        }
        EventLoopFuture.whenAllComplete(futures, on: eventLoop)
            .always { _ in
                XCTAssertEqual(ConnectionCounter.deletedCounter, 0)
            }
            .flatMap { _ in
                pool.close(logger: Self.logger)
            }
            .whenComplete { _ in
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(ConnectionCounter.counter, 4)
    }
    
    func testCheckCloseFlag() throws {
        /// connection that keeps count of instance
        final class ConnectionCounter: HBConnection {
            static func make(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<ConnectionCounter> {
                return eventLoop.makeSucceededFuture(.init(eventLoop: eventLoop))
            }
            static var counter: Int = 0
            static var deletedCounter: Int = 0
            
            let eventLoop: EventLoop
            var isClosed: Bool
            
            init(eventLoop: EventLoop) {
                self.eventLoop = eventLoop
                self.isClosed = false
                Self.counter += 1
            }
            
            deinit {
                Self.deletedCounter += 1
            }

            func close(logger: Logger) -> EventLoopFuture<Void> {
                self.isClosed = true
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<ConnectionCounter>(maxConnections: 4, eventLoop: eventLoop)
        let c = try pool.request(logger: Self.logger).wait()
        pool.release(connection: c, logger: Self.logger)
        c.isClosed = true
        _ = try pool.request(logger: Self.logger).wait()
        XCTAssertEqual(ConnectionCounter.deletedCounter, 1)
        XCTAssertEqual(ConnectionCounter.counter, 2)

        try pool.close(logger: Self.logger).wait()
    }
    
    func testClosing() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<Connection>(maxConnections: 1, eventLoop: eventLoop)
        try pool.close(logger: Self.logger).wait()
        do {
            _ = try pool.request(logger: Self.logger).wait()
            XCTFail()
        } catch HBConnectionPoolError.poolClosed {
        } catch {
            XCTFail()
        }
    }
    
    func testWaitingClosing() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool<Connection>(maxConnections: 1, eventLoop: eventLoop)
        _ = try pool.request(logger: Self.logger).wait()
        let c2Future = pool.request(logger: Self.logger)
        try pool.close(logger: Self.logger).wait()
        do {
            _ = try c2Future.wait()
            XCTFail()
        } catch HBConnectionPoolError.poolClosed {
        } catch {
            XCTFail()
        }
    }
}
