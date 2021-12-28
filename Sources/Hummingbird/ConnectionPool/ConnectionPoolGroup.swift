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
import NIOCore

/// Array of connection pools associated with an EventLoopGroup.
///
/// Each EventLoop has a connection pool associated with it
public class HBConnectionPoolGroup<Connection: HBConnection> {
    let pools: [EventLoop.Key: HBConnectionPool<Connection>]
    let eventLoopGroup: EventLoopGroup
    let logger: Logger

    /// Create `HBConnectionPoolGroup`
    ///
    /// - Parameters:
    ///     - maxConnections: Maximum connections each EventLoop can make
    ///     - eventLoopGroup: `EventLoopGroup`` associated with this `HBConnectionPoolGroup`
    public init(maxConnections: Int, eventLoopGroup: EventLoopGroup, logger: Logger) {
        var pools: [EventLoop.Key: HBConnectionPool<Connection>] = [:]
        for eventLoop in eventLoopGroup.makeIterator() {
            pools[eventLoop.key] = HBConnectionPool(maxConnections: maxConnections, eventLoop: eventLoop)
        }
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        self.pools = pools
    }

    /// Request a connection, run a process and then release the connection
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   -logger: Logger used for logging
    ///   - process: Closure to run while we have the connection 
    public func lease<NewValue>(
        on eventLoop: EventLoop, 
        logger: Logger, 
        process: @escaping (Connection)->EventLoopFuture<NewValue>
    ) -> EventLoopFuture<NewValue> {
        let pool = getConnectionPool(on: eventLoop)
        return pool.lease(logger: logger, process: process)
    }

    /// Request a connection
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   - logger: Logger used for logging
    /// - Returns: Returns a connection when available
    public func request(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Connection> {
        let pool = getConnectionPool(on: eventLoop)
        return pool.request(logger: logger)
    }

    /// Release a connection back onto the pool
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   - logger: Logger used for logging
    public func release(connection: Connection, on eventLoop: EventLoop, logger: Logger) {
        let pool = getConnectionPool(on: eventLoop)
        pool.release(connection: connection, logger: logger)
    }

    /// Return Connection Pool associated with EventLoopGroup
    public func getConnectionPool(on eventLoop: EventLoop) -> HBConnectionPool<Connection> {
        let pool = self.pools[eventLoop.key]
        assert(pool != nil, "No connection pool available for event loop")
        return pool!
    }

    /// Close connection pool group
    public func close() -> EventLoopFuture<Void> {
        let closeFutures: [EventLoopFuture<Void>] = self.pools.values.map { $0.close(logger: self.logger) }
        return EventLoopFuture.andAllComplete(closeFutures, on: self.eventLoopGroup.any())
    }
}
