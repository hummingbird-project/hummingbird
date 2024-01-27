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

import HummingbirdCore
import HummingbirdTLS
import HummingbirdXCT
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import NIOTransportServices
import XCTest

class HummingBirdTLSTests: XCTestCase {
    func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .tls(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "HB"),
            clientConfiguration: .init(tlsConfiguration: getClientTLSConfiguration(), serverName: testServerName)
        ) { client in
            let response = try await client.get("/")
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
    }
}
