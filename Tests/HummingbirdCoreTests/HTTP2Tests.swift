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

import AsyncHTTPClient
import HummingbirdCore
import HummingbirdHTTP2
import HummingbirdTesting
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import NIOTransportServices
import XCTest

class HummingBirdHTTP2Tests: XCTestCase {
    func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        try await testServer(
            responder: { _, _ in
                .init(status: .ok)
            },
            httpChannelSetup: .http2Upgrade(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { _, port in
            var tlsConfiguration = try getClientTLSConfiguration()
            // no way to override the SSL server name with AsyncHTTPClient so need to set
            // hostname verification off
            tlsConfiguration.certificateVerification = .noHostnameVerification
            let httpClient = HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: .init(tlsConfiguration: tlsConfiguration)
            )
            defer { try? httpClient.syncShutdown() }

            let response = try await httpClient.get(url: "https://localhost:\(port)/").get()
            XCTAssertEqual(response.status, .ok)
        }
    }
}
