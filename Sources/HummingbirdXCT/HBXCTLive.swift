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
import HummingbirdCore
import HummingbirdCoreXCT
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTransportServices
import ServiceLifecycle
import XCTest

/// Test using a live server
final class HBXCTLive<App: HBApplication>: HBXCTApplication where App.Responder.Context: HBRequestContext {
    /// TestApplication used to wrap HBApplication being tested
    struct TestApplication<BaseApp: HBApplication>: HBApplication {
        typealias Context = BaseApp.Context
        typealias Responder = BaseApp.Responder
        typealias ChannelSetup = BaseApp.ChannelSetup

        let base: BaseApp

        func buildResponder() async throws -> Responder {
            try await base.buildResponder()
        }

        func buildChannelSetup(httpResponder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse) throws -> ChannelSetup {
            try base.buildChannelSetup(httpResponder: httpResponder)
        }

        /// event loop group used by application
        var eventLoopGroup: EventLoopGroup { base.eventLoopGroup }
        /// thread pool used by application
        var threadPool: NIOThreadPool { base.threadPool }
        /// Configuration
        var configuration: HBApplicationConfiguration { base.configuration.with(address: .hostname("localhost", port: 0)) }
        /// Logger
        var logger: Logger { base.logger }
        /// Encoder used by router
        var encoder: HBResponseEncoder  { base.encoder }
        /// decoder used by router
        var decoder: HBRequestDecoder { base.decoder }
        /// on server running
        @Sendable func onServerRunning(_ channel: Channel) async {
            await portPromise.complete(channel.localAddress!.port!)
        }
        /// services attached to the application.
        var services: [any Service] { base.services }

        let portPromise: Promise<Int> = .init()
    }
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
