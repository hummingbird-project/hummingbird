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

import HummingbirdCore
import HummingbirdTesting
import Logging
import NIOCore
import NIOSSL
import ServiceLifecycle
import XCTest

public enum TestErrors: Error {
    case timeout
}

/// Basic responder that just returns "Hello" in body
@Sendable public func helloResponder(to request: Request, channel: Channel) async -> Response {
    let responseBody = channel.allocator.buffer(string: "Hello")
    return Response(status: .ok, body: .init(byteBuffer: responseBody))
}

/// Helper function for testing a server
public func testServer<Value: Sendable>(
    responder: @escaping HTTPChannelHandler.Responder,
    httpChannelSetup: HTTPServerBuilder,
    configuration: ServerConfiguration,
    eventLoopGroup: EventLoopGroup,
    logger: Logger,
    _ test: @escaping @Sendable (Int) async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Void.self) { group in
        let promise = Promise<Int>()
        let server = try httpChannelSetup.buildServer(
            configuration: configuration,
            eventLoopGroup: eventLoopGroup,
            logger: logger,
            responder: responder,
            onServerRunning: { await promise.complete($0.localAddress!.port!) }
        )
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [server],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: logger
            )
        )

        group.addTask {
            try await serviceGroup.run()
        }
        let value = try await test(promise.wait())
        await serviceGroup.triggerGracefulShutdown()
        return value
    }
}

/// Helper function for test a server
///
/// Creates test client, runs test function abd ensures everything is
/// shutdown correctly
public func testServer<Value: Sendable>(
    responder: @escaping HTTPChannelHandler.Responder,
    httpChannelSetup: HTTPServerBuilder = .http1(),
    configuration: ServerConfiguration,
    eventLoopGroup: EventLoopGroup,
    logger: Logger,
    clientConfiguration: TestClient.Configuration = .init(),
    _ test: @escaping @Sendable (TestClient) async throws -> Value
) async throws -> Value {
    try await testServer(
        responder: responder,
        httpChannelSetup: httpChannelSetup,
        configuration: configuration,
        eventLoopGroup: eventLoopGroup,
        logger: logger
    ) { port in
        let client = TestClient(
            host: "localhost",
            port: port,
            configuration: clientConfiguration,
            eventLoopGroupProvider: .createNew
        )
        client.connect()
        let value = try await test(client)
        try await client.shutdown()
        return value
    }
}

/// Run process with a timeout
/// - Parameters:
///   - timeout: Amount of time before timeout error is thrown
///   - process: Process to run
public func withTimeout(_ timeout: TimeAmount, _ process: @escaping @Sendable () async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await Task.sleep(nanoseconds: numericCast(timeout.nanoseconds))
            throw TestErrors.timeout
        }
        group.addTask {
            try await process()
        }
        try await group.next()
        group.cancelAll()
    }
}

/// Promise type.
actor Promise<Value> {
    enum State {
        case blocked([CheckedContinuation<Value, Never>])
        case unblocked(Value)
    }

    var state: State

    init() {
        self.state = .blocked([])
    }

    /// wait from promise to be completed
    func wait() async -> Value {
        switch self.state {
        case .blocked(var continuations):
            return await withCheckedContinuation { cont in
                continuations.append(cont)
                self.state = .blocked(continuations)
            }
        case .unblocked(let value):
            return value
        }
    }

    /// complete promise with value
    func complete(_ value: Value) {
        switch self.state {
        case .blocked(let continuations):
            for cont in continuations {
                cont.resume(returning: value)
            }
            self.state = .unblocked(value)
        case .unblocked:
            break
        }
    }
}
