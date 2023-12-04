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
import Logging
import NIOCore
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import XCTest

/// Test using a live server
final class HBXCTLive<App: HBApplicationProtocol>: HBXCTApplication where App.Context: HBRequestContext {
    /// TestApplication used to wrap HBApplication being tested
    struct TestApplication<BaseApp: HBApplicationProtocol>: HBApplicationProtocol, Service where BaseApp.Context: HBRequestContext {
        typealias Context = BaseApp.Context
        typealias Responder = BaseApp.Responder
        typealias ChannelSetup = BaseApp.ChannelSetup

        let base: BaseApp

        func buildResponder() async throws -> Responder {
            try await self.base.buildResponder()
        }

        func channelSetup(httpResponder: @escaping @Sendable (HBRequest, Channel) async throws -> HBResponse) throws -> ChannelSetup {
            try self.base.channelSetup(httpResponder: httpResponder)
        }

        /// event loop group used by application
        var eventLoopGroup: EventLoopGroup { self.base.eventLoopGroup }
        /// Configuration
        var configuration: HBApplicationConfiguration { self.base.configuration.with(address: .hostname("localhost", port: 0)) }
        /// Logger
        var logger: Logger { self.base.logger }
        /// on server running
        @Sendable func onServerRunning(_ channel: Channel) async {
            await self.portPromise.complete(channel.localAddress!.port!)
        }

        /// services attached to the application.
        var services: [any Service] { self.base.services }

        let portPromise: Promise<Int> = .init()
    }

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

    init(app: App) {
        self.timeout = .seconds(15)
        self.application = TestApplication(base: app)
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
            let port = await self.application.portPromise.wait()
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

    let application: TestApplication<App>
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
