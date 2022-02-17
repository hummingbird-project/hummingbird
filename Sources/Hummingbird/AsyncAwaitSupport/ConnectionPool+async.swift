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

#if compiler(>=5.5) && canImport(_Concurrency)

import Logging
import NIO

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBConnectionPool {
    /// Request a connection, run a process and then release the connection
    /// - Parameters:
    ///   -logger: Logger used for logging
    ///   - process: Closure to run while we have the connection
    public func lease<NewValue>(logger: Logger, process: @escaping (Source.Connection) async throws -> NewValue) async throws -> NewValue {
        return try await self.lease(logger: logger) { connection in
            let promise = self.eventLoop.makePromise(of: NewValue.self)
            promise.completeWithTask {
                return try await process(connection)
            }
            return promise.futureResult
        }.get()
    }

    /// Request a connection
    /// - Parameter logger: Logger used for logging
    /// - Returns: Returns a connection when available
    public func request(logger: Logger) async throws -> Source.Connection {
        return try await self.request(logger: logger).get()
    }

    /// Close connection pool
    /// - Parameter logger: Logger used for logging
    /// - Returns: Returns when close is complete
    public func close(logger: Logger) async throws {
        return try await self.close(logger: logger).get()
    }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension HBConnectionPoolGroup {
    /// Request a connection, run a process and then release the connection
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   -logger: Logger used for logging
    ///   - process: Closure to run while we have the connection
    public func lease<NewValue>(
        on eventLoop: EventLoop,
        logger: Logger,
        process: @escaping (Source.Connection) async throws -> NewValue
    ) async throws -> NewValue {
        let pool = self.getConnectionPool(on: eventLoop)
        return try await pool.lease(logger: logger, process: process)
    }

    /// Request a connection
    /// - Parameters:
    ///   - eventLoop: event loop to find associated connection pool
    ///   - logger: Logger used for logging
    /// - Returns: Returns a connection when available
    public func request(on eventLoop: EventLoop, logger: Logger) async throws -> Source.Connection {
        let pool = self.getConnectionPool(on: eventLoop)
        return try await pool.request(logger: logger)
    }

    /// Close connection pool group
    public func close() async throws {
        return try await self.close().get()
    }
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public protocol HBConnectionAsyncSource: HBConnectionSource {
    func makeConnection(on eventLoop: EventLoop, logger: Logger) async throws -> Connection
}

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public extension HBConnectionAsyncSource {
    func makeConnection(on eventLoop: EventLoop, logger: Logger) -> EventLoopFuture<Connection> {
        let promise = eventLoop.makePromise(Connection.self)
        promise.completeWithTask {
            return try await makeConnection(on: eventLoop, logger: logger)
        }
        return promise.futureResult
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
