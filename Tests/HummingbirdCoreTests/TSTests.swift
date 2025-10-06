//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Network)

import Foundation
import HummingbirdCore
import HummingbirdTesting
import Logging
import Network
import NIOCore
import NIOSSL
import NIOTransportServices
import Testing

struct TransportServicesTests {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    @Test func testConnect() async throws {
        try await testServer(
            responder: helloResponder,
            configuration: .init(address: .hostname(port: 0)),
            eventLoopGroup: NIOSingletons.transportServicesEventLoopGroup,
            logger: Logger(label: "Hummingbird")
        ) { client in
            let response = try await client.get("/")
            var body = try #require(response.body)
            #expect(body.readString(length: body.readableBytes) == "Hello")
        }
    }

    @Test func testTLS() async throws {
        let p12Path = Bundle.module.path(forResource: "server", ofType: "p12")!
        await withKnownIssue("Loading p12 files in CI can fail with `interactionNotAllowed` error", isIntermittent: true) {
            let identity = try TSTLSOptions.Identity.p12(filename: p12Path, password: "HBTests")
            let tlsOptions = try #require(TSTLSOptions.options(serverIdentity: identity))

            try await testServer(
                responder: helloResponder,
                configuration: .init(address: .hostname(port: 0), serverName: testServerName, tlsOptions: tlsOptions),
                eventLoopGroup: NIOSingletons.transportServicesEventLoopGroup,
                logger: Logger(label: "Hummingbird"),
                clientConfiguration: .init(tlsConfiguration: self.getClientTLSConfiguration(), serverName: testServerName)
            ) { client in
                let response = try await client.get("/")
                var body = try #require(response.body)
                #expect(body.readString(length: body.readableBytes) == "Hello")
            }
        }
    }

    func getClientTLSConfiguration() throws -> TLSConfiguration {
        let caCertificate = try NIOSSLCertificate(bytes: [UInt8](caCertificateData.utf8), format: .pem)
        let certificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: [UInt8](clientPrivateKeyData.utf8), format: .pem)
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.trustRoots = .certificates([caCertificate])
        tlsConfig.certificateChain = [.certificate(certificate)]
        tlsConfig.privateKey = .privateKey(privateKey)
        return tlsConfig
    }
}

#endif
