//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HummingbirdCore
import HummingbirdTLS
import HummingbirdTesting
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import NIOSSL
import Testing

struct HummingBirdTLSTests {
    @Test func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .tls(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "Hummingbird"),
            clientConfiguration: .init(tlsConfiguration: getClientTLSConfiguration(), serverName: testServerName)
        ) { client in
            let response = try await client.get("/")
            var body = try #require(response.body)
            #expect(body.readString(length: body.readableBytes) == "Hello")
        }
    }

    @Test func testGracefulShutdownWithDanglingConnection() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
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
        let channel = try clientChannel.withLockedValue { try #require($0) }
        try await channel.closeFuture.get()
    }

    @Test func testCustomVerify() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        let verifiedResult = NIOLockedValueBox<NIOSSLVerificationResult>(.certificateVerified)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        var tlsConfig = try getServerTLSConfiguration()
        tlsConfig.certificateVerification = .noHostnameVerification
        try await testServer(
            responder: helloResponder,
            httpChannelSetup: .tls(
                configuration: .init(
                    tlsConfiguration: tlsConfig,
                    customAsyncVerificationCallback: { _ in
                        verifiedResult.withLockedValue { $0 }
                    }
                )
            ),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { port in
            try await TestClient.withClient(
                host: "localhost",
                port: port,
                configuration: .init(tlsConfiguration: getClientTLSConfiguration(), serverName: testServerName)
            ) { client in
                let response = try await client.get("/")
                var body = try #require(response.body)
                #expect(body.readString(length: body.readableBytes) == "Hello")
            }
            // set certificate verification to fail
            verifiedResult.withLockedValue { $0 = .failed }
            do {
                try await TestClient.withClient(
                    host: "localhost",
                    port: port,
                    configuration: .init(tlsConfiguration: getClientTLSConfiguration(), serverName: testServerName)
                ) { client in
                    _ = try await client.get("/")
                }
                Issue.record("Client connection should fail as certificate verification is set to fail")
            } catch BoringSSLError.sslError {
            } catch {
                print("\(error)")
            }

        }
    }
}
