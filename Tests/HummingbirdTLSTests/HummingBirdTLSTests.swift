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

import HummingbirdCore
import HummingbirdCoreXCT
import HummingbirdTLS
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOSSL
import NIOTransportServices
import XCTest

class HummingBirdTLSTests: XCTestCase {
    struct HelloResponder: HBHTTPResponder {
        func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
            let responseBody = context.channel.allocator.buffer(string: "Hello")
            let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
            onComplete(.success(response))
        }

        var logger: Logger? = Logger(label: "Core")

        init() {
            self.logger?.logLevel = .trace
        }
    }

    func testConnect() throws {
        #if os(iOS)
        let eventLoopGroup = NIOTSEventLoopGroup()
        #else
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        #endif
        defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 0), serverName: testServerName))
        try server.addTLS(tlsConfiguration: self.getServerTLSConfiguration())
        try server.start(responder: HelloResponder()).wait()
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = try HBXCTClient(
            host: "localhost",
            port: server.port!,
            configuration: .init(tlsConfiguration: self.getClientTLSConfiguration(), serverName: testServerName),
            eventLoopGroupProvider: .createNew
        )
        client.connect()
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get("/").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), "Hello")
        }
        XCTAssertNoThrow(try future.wait())
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
        return tlsConfig
    }
}
