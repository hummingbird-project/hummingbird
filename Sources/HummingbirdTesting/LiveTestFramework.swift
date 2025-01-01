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
import Logging
import NIOCore
import NIOPosix
import ServiceLifecycle

/// Test using a live server
final class LiveTestFramework<App: ApplicationProtocol>: ApplicationTestFramework {
    struct Client: TestClientProtocol {
        let client: TestClient

        /// Send request and call test callback on the response returned
        func executeRequest(
            uri: String,
            method: HTTPRequest.Method,
            headers: HTTPFields = [:],
            body: ByteBuffer? = nil
        ) async throws -> TestResponse {
            var headers = headers
            headers[.connection] = "keep-alive"
            let request = TestClient.Request(uri, method: method, authority: "localhost", headers: headers, body: body)
            let response = try await client.execute(request)
            return .init(head: response.head, body: response.body ?? ByteBuffer(), trailerHeaders: response.trailerHeaders)
        }

        var port: Int? { self.client.port }
    }

    init(app: App) {
        self.timeout = .seconds(20)
        self.application = TestApplication(base: app)
    }

    /// Start tests
    func run<Value>(_ test: @Sendable (TestClientProtocol) async throws -> Value) async throws -> Value {
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
            let client = TestClient(
                host: "localhost",
                port: port,
                configuration: .init(timeout: self.timeout),
                eventLoopGroupProvider: .createNew
            )
            client.connect()
            do {
                let value = try await test(Client(client: client))
                try await client.shutdown()
                await serviceGroup.triggerGracefulShutdown()
                return value
            } catch {
                try await client.shutdown()
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }

    let application: TestApplication<App>
    let timeout: Duration
}
