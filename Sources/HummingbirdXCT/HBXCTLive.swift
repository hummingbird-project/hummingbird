//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdCoreXCT
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import XCTest

/// Test using a live server
final class HBXCTLive: HBXCT {
    struct Client: HBXCTClientProtocol {
        let client: HBXCTClient

        /// Send request and call test callback on the response returned
        func execute(
            uri: String,
            method: HTTPMethod,
            headers: HTTPHeaders = [:],
            body: ByteBuffer? = nil
        ) async throws -> HBXCTResponse {
            var headers = headers
            headers.replaceOrAdd(name: "connection", value: "keep-alive")
            headers.replaceOrAdd(name: "host", value: "localhost")
            let request = HBXCTClient.Request(uri, method: method, headers: headers, body: body)
            let response = try await client.execute(request)
            return .init(status: response.status, headers: response.headers, body: response.body)
        }
    }

    init(configuration: HBApplication.Configuration, timeout: TimeAmount) {
        self.timeout = timeout
        self.promise = .init()
        #if os(iOS)
        self.eventLoopGroup = NIOTSEventLoopGroup()
        #else
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        #endif
    }

    /// Start tests
    func run(application: HBApplication, _ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                services: [application],
                configuration: .init(gracefulShutdownSignals: [.sigterm, .sigint]),
                logger: application.logger
            )
            group.addTask {
                try await serviceGroup.run()
            }
            let port = await self.promise.wait()
            let client = HBXCTClient(
                host: "localhost",
                port: port,
                configuration: .init(timeout: .seconds(2)),
                eventLoopGroupProvider: .createNew
            )
            client.connect()
            group.addTask {
                _ = try await test(Client(client: client))
            }
            try await group.next()
            await serviceGroup.triggerGracefulShutdown()
            try await client.shutdown()
        }
    }

    func onServerRunning(_ channel: Channel) async {
        await self.promise.complete(channel.localAddress!.port!)
    }

    let eventLoopGroup: EventLoopGroup
    let promise: Promise<Int>
    let timeout: TimeAmount
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
