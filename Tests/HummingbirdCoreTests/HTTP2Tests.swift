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
import HummingbirdXCT
import HummingbirdHTTP2
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
            httpChannelSetup: .http2(tlsConfiguration: self.getServerTLSConfiguration()),
            configuration: .init(address: .hostname(port: 0), serverName: testServerName),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "HB")
        ) { _, port in
            let httpClient = try HTTPClient(
                eventLoopGroupProvider: .shared(eventLoopGroup),
                configuration: .init(tlsConfiguration: self.getClientTLSConfiguration())
            )
            defer { try? httpClient.syncShutdown() }

            let response = try await httpClient.get(url: "https://localhost:\(port)/").get()
            XCTAssertEqual(response.status, .ok)
        }
    }

    func getServerTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
        let certificate = try NIOSSLCertificate(bytes: [UInt8](serverCertificateData.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](serverPrivateKeyData.utf8), format: .pem)
        var tlsConfig = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
        tlsConfig.trustRoots = .certificates([caCertificate])
        return tlsConfig
    }

    func getClientTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
        let certificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](clientPrivateKeyData.utf8), format: .pem)
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.trustRoots = .certificates([caCertificate])
        tlsConfig.certificateChain = [.certificate(certificate)]
        tlsConfig.privateKey = .privateKey(privateKey)
        tlsConfig.certificateVerification = .noHostnameVerification
        return tlsConfig
    }
}
