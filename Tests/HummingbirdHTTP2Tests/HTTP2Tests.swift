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
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOHTTPTypes
import NIOPosix
import NIOSSL
import ServiceLifecycle
import Testing

struct HummingBirdHTTP2Tests {
    @Test func testConnect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer {
            #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() }
        }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace

        var tlsConfiguration = try getClientTLSConfiguration()
        // no way to override the SSL server name with AsyncHTTPClient so need to set
        // hostname verification off
        tlsConfiguration.certificateVerification = .noHostnameVerification
        try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
            try await testServer(
                responder: { (_, responseWriter: consuming ResponseWriter, _) in
                    try await responseWriter.writeResponse(.init(status: .ok))
                },
                httpChannelSetup: .http2Upgrade(tlsConfiguration: getServerTLSConfiguration()),
                configuration: .init(address: .hostname(port: 0), serverName: testServerName),
                eventLoopGroup: eventLoopGroup,
                logger: logger
            ) { port in
                let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testCustomVerify() async throws {
        let verifiedResult = NIOLockedValueBox<NIOSSLVerificationResult>(.certificateVerified)
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer {
            #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() }
        }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .debug

        var serverTLSConfig = try getServerTLSConfiguration()
        serverTLSConfig.certificateVerification = .noHostnameVerification
        try await testServer(
            responder: { (_, responseWriter: consuming ResponseWriter, _) in
                try await responseWriter.writeResponse(.init(status: .ok))
            },
            httpChannelSetup: .http2Upgrade(
                tlsChannelConfiguration: .init(
                    tlsConfiguration: serverTLSConfig
                ) { certs, promise in
                    promise.succeed(verifiedResult.withLockedValue { $0 })
                }
            ),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: logger
        ) { port in
            var tlsConfiguration = try getClientTLSConfiguration()
            // no way to override the SSL server name with AsyncHTTPClient so need to set
            // hostname verification off
            tlsConfiguration.certificateVerification = .noHostnameVerification
            try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
                let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                #expect(response.status == .ok)
            }
            // set certicate verification to fail
            verifiedResult.withLockedValue { $0 = .failed }

            await #expect(throws: HTTPClientError.remoteConnectionClosed) {
                try await withHTTPClient(
                    .init(
                        tlsConfiguration: tlsConfiguration,
                        timeout: .init(connect: .seconds(2), read: .seconds(2))
                    )
                ) {
                    httpClient in
                    let request2 = HTTPClientRequest(url: "https://localhost:\(port)/")
                    let response2 = try await httpClient.execute(request2, deadline: .now() + .seconds(30))
                    print(response2)
                }
            }
        }

    }

    @Test func testMultipleSerialRequests() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace

        var tlsConfiguration = try getClientTLSConfiguration()
        // no way to override the SSL server name with AsyncHTTPClient so need to set
        // hostname verification off
        tlsConfiguration.certificateVerification = .noHostnameVerification
        try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
            try await testServer(
                responder: { (_, responseWriter: consuming ResponseWriter, _) in
                    try await responseWriter.writeResponse(.init(status: .ok))
                },
                httpChannelSetup: .http2Upgrade(tlsConfiguration: getServerTLSConfiguration()),
                configuration: .init(address: .hostname(port: 0), serverName: testServerName),
                eventLoopGroup: eventLoopGroup,
                logger: logger
            ) { port in
                let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                for _ in 0..<16 {
                    let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                    _ = try await response.body.collect(upTo: .max)
                    #expect(response.status == .ok)
                }
            }
        }
    }

    @Test func testMultipleConcurrentRequests() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace

        var tlsConfiguration = try getClientTLSConfiguration()
        // no way to override the SSL server name with AsyncHTTPClient so need to set
        // hostname verification off
        tlsConfiguration.certificateVerification = .noHostnameVerification
        try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
            try await testServer(
                responder: { (_, responseWriter: consuming ResponseWriter, _) in
                    try await responseWriter.writeResponse(.init(status: .ok))
                },
                httpChannelSetup: .http2Upgrade(tlsConfiguration: getServerTLSConfiguration()),
                configuration: .init(address: .hostname(port: 0), serverName: testServerName),
                eventLoopGroup: eventLoopGroup,
                logger: logger
            ) { port in
                let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for _ in 0..<16 {
                            let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                            _ = try await response.body.collect(upTo: .max)
                            #expect(response.status == .ok)
                        }
                    }
                    try await group.waitForAll()
                }
            }
        }
    }

    @Test func testConnectionClosed() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace

        try await testServer(
            responder: { (_, responseWriter: consuming ResponseWriter, _) in
                try await responseWriter.writeResponse(.init(status: .ok))
            },
            httpChannelSetup: .http2Upgrade(
                tlsConfiguration: getServerTLSConfiguration()
            ),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: logger,
            test: { port in
                var tlsConfiguration = try getClientTLSConfiguration()
                // no way to override the SSL server name with AsyncHTTPClient so need to set
                // hostname verification off
                tlsConfiguration.certificateVerification = .noHostnameVerification
                try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
                    let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                    let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                    #expect(response.status == .ok)
                }
            }
        )
    }

    @Test func testHTTP1Connect() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer { #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() } }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace
        try await testServer(
            responder: { (_, responseWriter: consuming ResponseWriter, _) in
                try await responseWriter.writeResponse(.init(status: .ok))
            },
            httpChannelSetup: .http2Upgrade(tlsConfiguration: getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: logger,
            test: { port in
                var tlsConfiguration = try getClientTLSConfiguration()
                // no way to override the SSL server name with AsyncHTTPClient so need to set
                // hostname verification off
                tlsConfiguration.certificateVerification = .noHostnameVerification
                let client = TestClient(
                    host: "localhost",
                    port: port,
                    configuration: .init(tlsConfiguration: tlsConfiguration),
                    eventLoopGroupProvider: .shared(eventLoopGroup)
                )
                client.connect()
                let response: TestClient.Response
                do {
                    response = try await client.get("/")
                } catch {
                    try? await client.shutdown()
                    throw error
                }
                try await client.shutdown()
                #expect(response.status == .ok)
            }
        )
    }

    func testChildChannelGracefulShutdown() async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        defer {
            #expect(throws: Never.self) { try eventLoopGroup.syncShutdownGracefully() }
        }
        var logger = Logger(label: "Hummingbird")
        logger.logLevel = .trace

        var tlsConfiguration = try getClientTLSConfiguration()
        // no way to override the SSL server name with AsyncHTTPClient so need to set
        // hostname verification off
        tlsConfiguration.certificateVerification = .noHostnameVerification
        try await withHTTPClient(.init(tlsConfiguration: tlsConfiguration)) { httpClient in
            try await withThrowingTaskGroup(of: Void.self) { group in
                let promise = Promise<Int>()
                let server = try HTTPServerBuilder.http2Upgrade(tlsConfiguration: getServerTLSConfiguration()).buildServer(
                    configuration: .init(address: .hostname(port: 0), serverName: testServerName),
                    eventLoopGroup: eventLoopGroup,
                    logger: logger,
                    responder: { (_, responseWriter: consuming ResponseWriter, _) in
                        try await Task.sleep(for: .seconds(2))
                        try await responseWriter.writeResponse(.init(status: .ok))
                    },
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

                let port = await promise.wait()
                group.addTask {
                    let request = HTTPClientRequest(url: "https://localhost:\(port)/")
                    let response = try await httpClient.execute(request, deadline: .now() + .seconds(30))
                    #expect(response.status == .ok)
                }
                try await Task.sleep(for: .milliseconds(500))
                await serviceGroup.triggerGracefulShutdown()
            }
        }
    }

}
