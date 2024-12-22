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
import HummingbirdTesting
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import NIOSSL
import NIOTransportServices
import XCTest

final class HummingBirdTLSTests: XCTestCase {
    func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .tls(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "Hummingbird"),
            clientConfiguration: .init(tlsConfiguration: getClientTLSConfiguration(), serverName: testServerName)
        ) { client in
            let response = try await client.get("/")
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
    }

    func testGracefulShutdownWithDanglingConnection() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        let clientChannel: NIOLockedValueBox<Channel?> = .init(nil)
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .tls(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { port in
            let channel = try await ClientBootstrap(group: eventLoopGroup)
                .connect(host: "127.0.0.1", port: port).get()
            clientChannel.withLockedValue { $0 = channel }
        }
        // test channel has been closed
        let channel = try clientChannel.withLockedValue { try XCTUnwrap($0) }
        try await channel.closeFuture.get()
    }
}
