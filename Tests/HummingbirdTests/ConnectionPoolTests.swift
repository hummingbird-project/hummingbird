//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import Hummingbird
import Logging
import NIOCore
import NIOPosix
import XCTest

final class ConnectionPoolTests: XCTestCase {
    final class Connection: HBConnection {
        var isClosed: Bool

        init() {
            self.isClosed = false
        }

        func close(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
            self.isClosed = true
            return eventLoop.makeSucceededVoidFuture()
        }
    }

    struct ConnectionSource: HBConnectionSource {
        func makeConnection(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Connection> {
            return eventLoop.makeSucceededFuture(.init())
        }
    }

    static var logger = Logger(label: "ConnectionPoolTests")
    static var eventLoopGroup: EventLoopGroup!

    override static func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.logger.logLevel = .trace
    }

    override static func tearDown() {
        XCTAssertNoThrow(try self.eventLoopGroup.syncShutdownGracefully())
    }

    /// test request and releasing a connection
    func testRequestRelease() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: ConnectionSource(), maxConnections: 4, eventLoop: eventLoop)
        let c = try pool.request(logger: Self.logger).wait()
        pool.release(connection: c, logger: Self.logger)
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            XCTAssertEqual(pool.availableQueue.count, 1)
            return pool.close(logger: Self.logger)
        }.wait()
    }

    /// test waiting on a connection when one isn't available
    func testWaiting() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: ConnectionSource(), maxConnections: 1, eventLoop: eventLoop)
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

    /// test requesting and releasing multiple connections
    func testMultiRequestRelease() throws {
        /// connection that keeps count of instance
        final class ConnectionCounter: HBConnection {
            static var counter: Int = 0
            static var deletedCounter: Int = 0

            var isClosed: Bool

            init() {
                self.isClosed = false
                Self.counter += 1
            }

            deinit {
                Self.deletedCounter += 1
            }

            func close(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                self.isClosed = true
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        struct CounterConnectionSource: HBConnectionSource {
            func makeConnection(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<ConnectionCounter> {
                return eventLoop.makeSucceededFuture(.init())
            }
        }
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 1
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: CounterConnectionSource(), maxConnections: 4, eventLoop: eventLoop)
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
                XCTAssertEqual(pool.availableQueue.count, 4)
            }
            .flatMap { _ in
                pool.close(logger: Self.logger)
            }
            .whenComplete { _ in
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 1.0)
        // test number of connections open is the maxConnections
        XCTAssertEqual(ConnectionCounter.counter, 4)
    }

    /// Test closed connection is purged
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

            func close(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
                self.isClosed = true
                return eventLoop.makeSucceededVoidFuture()
            }
        }
        struct CounterConnectionSource: HBConnectionSource {
            func makeConnection(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<ConnectionCounter> {
                return eventLoop.makeSucceededFuture(.init(eventLoop: eventLoop))
            }
        }
        let eventLoop = Self.eventLoopGroup.next()
        // run everything on same EventLoop so we can guarantee everything runs immediately
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let pool = HBConnectionPool(source: CounterConnectionSource(), maxConnections: 4, eventLoop: eventLoop)
            return pool.request(logger: Self.logger)
                .flatMap { c -> EventLoopFuture<ConnectionCounter> in
                    pool.release(connection: c, logger: Self.logger)
                    // close connection
                    c.isClosed = true
                    return pool.request(logger: Self.logger)
                }.map { _ in
                    XCTAssertEqual(ConnectionCounter.deletedCounter, 1)
                    XCTAssertEqual(ConnectionCounter.counter, 2)
                    XCTAssertEqual(pool.availableQueue.count, 0)
                }.flatMap { () -> EventLoopFuture<Void> in
                    return pool.close(logger: Self.logger)
                }
        }.wait()
    }

    /// Check `poolClosed` error is thrown when request a connectino of a closed pool
    func testClosing() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: ConnectionSource(), maxConnections: 1, eventLoop: eventLoop)
        try pool.close(logger: Self.logger).wait()
        do {
            _ = try pool.request(logger: Self.logger).wait()
            XCTFail()
        } catch HBConnectionPoolError.poolClosed {
        } catch {
            XCTFail()
        }
    }

    /// Test requests that are waiting for a connection are failed when pool is closed
    func testWaitingClosing() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: ConnectionSource(), maxConnections: 1, eventLoop: eventLoop)
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

    /// Test request and release connection from HBConnectionPoolGroup
    func testConnectionPoolGroup() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let poolGroup = HBConnectionPoolGroup(source: ConnectionSource(), maxConnections: 4, eventLoopGroup: Self.eventLoopGroup, logger: Self.logger)
        let c = try poolGroup.request(on: eventLoop, logger: Self.logger).wait()
        poolGroup.release(connection: c, on: eventLoop, logger: Self.logger)
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            XCTAssertEqual(poolGroup.getConnectionPool(on: eventLoop).availableQueue.count, 1)
            return poolGroup.close()
        }.wait()
    }

    /// Test leasing a connection from HBConnectionPoolGroup
    func testConnectionPoolGroupLease() throws {
        let eventLoop = Self.eventLoopGroup.next()
        let poolGroup = HBConnectionPoolGroup(source: ConnectionSource(), maxConnections: 4, eventLoopGroup: Self.eventLoopGroup, logger: Self.logger)
        let result = try poolGroup.lease(on: eventLoop, logger: Self.logger) { _ in
            return eventLoop.makeSucceededFuture(poolGroup.getConnectionPool(on: eventLoop).numConnections)
        }.wait()
        XCTAssertEqual(result, 1)
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            XCTAssertEqual(poolGroup.getConnectionPool(on: eventLoop).availableQueue.count, 1)
            return poolGroup.close()
        }.wait()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ConnectionPoolTests {
    final class AsyncConnection: HBAsyncConnection {
        var isClosed: Bool

        init() {
            self.isClosed = false
        }

        func close() async throws {
            self.isClosed = true
        }
    }

    struct AsyncConnectionSource: HBAsyncConnectionSource {
        typealias Connection = AsyncConnection
        func makeConnection(on eventLoop: NIOCore.EventLoop, logger: Logging.Logger) async throws -> Connection {
            return .init()
        }
    }

    /// test async version of request and releasing a connection
    func testAsyncRequestRelease() async throws {
        let eventLoop = Self.eventLoopGroup.next()
        let pool = HBConnectionPool(source: AsyncConnectionSource(), maxConnections: 4, eventLoop: eventLoop)
        let c = try await pool.request(logger: Self.logger)
        pool.release(connection: c, logger: Self.logger)

        // force event loop to flush release task
        try await eventLoop.submit {}.get()

        XCTAssertEqual(pool.availableQueue.count, 1)
        return try await pool.close(logger: Self.logger)
    }

    /// test async connection pool lease
    func testAsyncConnectionPoolGroupLease() async throws {
        let eventLoop = Self.eventLoopGroup.next()
        let poolGroup = HBConnectionPoolGroup(source: ConnectionSource(), maxConnections: 4, eventLoopGroup: Self.eventLoopGroup, logger: Self.logger)
        let result = try await poolGroup.lease(on: eventLoop, logger: Self.logger) { _ in
            return poolGroup.getConnectionPool(on: eventLoop).numConnections
        }
        XCTAssertEqual(result, 1)

        // force event loop to flush release task
        try await eventLoop.submit {}.get()

        XCTAssertEqual(poolGroup.getConnectionPool(on: eventLoop).availableQueue.count, 1)
        return try await poolGroup.close()
    }
}
