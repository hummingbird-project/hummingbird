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

import HummingbirdCore
import HummingbirdCoreXCT
import Logging
import Network
import NIOCore
import NIOHTTP1
import NIOSSL
import NIOTransportServices
import XCTest

@available(macOS 10.14, iOS 12, tvOS 12, *)
class TransportServicesTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    struct HelloResponder: HBHTTPResponder {
        func respond(to request: HBHTTPRequest, context: ChannelHandlerContext, onComplete: @escaping (Result<HBHTTPResponse, Error>) -> Void) {
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok)
            let responseBody = context.channel.allocator.buffer(string: "Hello")
            let response = HBHTTPResponse(head: responseHead, body: .byteBuffer(responseBody))
            onComplete(.success(response))
        }

        var logger: Logger
        init() {
            self.logger = Logger(label: "HB")
            self.logger.logLevel = .trace
        }
    }

    func testConnect() {
        let eventLoopGroup = NIOTSEventLoopGroup()
        let server = HBHTTPServer(group: eventLoopGroup, configuration: .init(address: .hostname(port: 0)))
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
        defer { XCTAssertNoThrow(try server.stop().wait()) }

        let client = HBXCTClient(
            host: "localhost",
            port: server.port!,
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

    func testTLS() throws {
        let eventLoopGroup = NIOTSEventLoopGroup()
        let p12Path = Bundle.module.path(forResource: "server", ofType: "p12")!
        let tlsOptions = try XCTUnwrap(TSTLSOptions.options(
            serverIdentity: .p12(filename: p12Path, password: "MyPassword")
        ))
        let configuration = HBHTTPServer.Configuration(
            address: .hostname(port: 0),
            serverName: testServerName,
            tlsOptions: tlsOptions
        )
        let server = HBHTTPServer(group: eventLoopGroup, configuration: configuration)
        XCTAssertNoThrow(try server.start(responder: HelloResponder()).wait())
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
