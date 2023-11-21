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

import HTTPTypes
import Hummingbird
import HummingbirdCore
import HummingbirdCoreXCT
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import XCTest

/// Test using a live server
final class HBXCTLive<Responder: HBResponder, ChannelSetup: HBChannelSetup & HTTPChannelHandler>: HBXCTApplication where Responder.Context: HBRequestContext {
    struct Client: HBXCTClientProtocol {
        let client: HBXCTClient

        /// Send request and call test callback on the response returned
        func execute(
            uri: String,
            method: HTTPRequest.Method,
            headers: HTTPFields = [:],
            body: ByteBuffer? = nil
        ) async throws -> HBXCTResponse {
            var headers = headers
            headers[.connection] = "keep-alive"
            let request = HBXCTClient.Request(uri, method: method, authority: "localhost", headers: headers, body: body)
            let response = try await client.execute(request)
            return .init(head: response.head, body: response.body)
        }
    }

    init(app: HBApplication<Responder, ChannelSetup>) {
        var app = app
        app.configuration = app.configuration.with(address: .hostname("localhost", port: 0))
        let promise = Promise<Int>()
        app.onServerRunning = { channel in
            await promise.complete(channel.localAddress!.port!)
        }
        self.timeout = .seconds(15)
        self.promise = promise
        self.application = app
    }

    /// Start tests
    func run<Value>(_ test: @escaping @Sendable (HBXCTClientProtocol) async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [self.application],
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: self.application.logger
                )
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
            let value = try await test(Client(client: client))
            await serviceGroup.triggerGracefulShutdown()
            try await client.shutdown()
            return value
        }
    }

    func onServerRunning(_ channel: Channel) async {
        await self.promise.complete(channel.localAddress!.port!)
    }

    let application: HBApplication<Responder, ChannelSetup>
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
