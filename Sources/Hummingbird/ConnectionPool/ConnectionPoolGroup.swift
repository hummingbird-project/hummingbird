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
public class HBConnectionPoolGroup<Source: HBConnectionSource> {
    let pools: [EventLoop.Key: HBConnectionPool<Source>]
    let eventLoopGroup: EventLoopGroup
    let logger: Logger

    /// Create `HBConnectionPoolGroup`
    ///
    /// - Parameters:
    ///     - maxConnections: Maximum connections each EventLoop can make
    ///     - eventLoopGroup: `EventLoopGroup`` associated with this `HBConnectionPoolGroup`
    public init(source: Source, maxConnections: Int, eventLoopGroup: EventLoopGroup, logger: Logger) {
        var pools: [EventLoop.Key: HBConnectionPool<Source>] = [:]
        for eventLoop in eventLoopGroup.makeIterator() {
            pools[eventLoop.key] = HBConnectionPool(source: source, maxConnections: maxConnections, eventLoop: eventLoop)
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
        process: @escaping (Source.Connection) -> EventLoopFuture<NewValue>
    ) -> EventLoopFuture<NewValue> {
        let pool = self.getConnectionPool(on: eventLoop)
        return pool.lease(logger: logger, process: process)
    }

    /// Request a connection
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   - logger: Logger used for logging
    /// - Returns: Returns a connection when available
    public func request(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Source.Connection> {
        let pool = self.getConnectionPool(on: eventLoop)
        return pool.request(logger: logger)
    }

    /// Release a connection back onto the pool
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   - logger: Logger used for logging
    public func release(connection: Source.Connection, on eventLoop: EventLoop, logger: Logger) {
        let pool = self.getConnectionPool(on: eventLoop)
        pool.release(connection: connection, logger: logger)
    }

    /// Return Connection Pool associated with EventLoopGroup
    public func getConnectionPool(on eventLoop: EventLoop) -> HBConnectionPool<Source> {
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
