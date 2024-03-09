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

import HTTPTypes
import HummingbirdCore
import HummingbirdTesting
import HummingbirdTLS
import Logging
import NIOCore
import NIOHTTPTypes
import NIOHTTPTypesHTTP1
import NIOPosix
#if canImport(Network)
import NIOTransportServices
#endif
import ServiceLifecycle
import XCTest

final class ClientTests: XCTestCase {
    enum ClientTLSConfiguration {
        case niossl(TLSConfiguration)
        #if canImport(Network)
        case ts(TSTLSOptions)
        #endif
        case none
    }

    let testClientChannel = HTTP1ClientChannel { inbound, outbound in
        let body = ByteBuffer(bytes: (0..<20000).map { _ in UInt8.random(in: 0...255) })
        try await outbound.writeRequest(
            .init(
                "/",
                method: .get,
                headers: [.contentLength: body.readableBytes.description],
                body: body
            )
        )
        var inboundIterator = inbound.makeAsyncIterator()
        let response = try await inboundIterator.readResponse()
        XCTAssertEqual(response.body, body)
    }

    func testClient(
        server: HBHTTPChannelBuilder<some HBServerChildChannel>,
        clientTLSConfiguration: ClientTLSConfiguration = .none,
        eventLoopGroup: EventLoopGroup
    ) async throws {
        let logger = {
            var logger = Logger(label: "TestClient")
            logger.logLevel = .trace
            return logger
        }()
        try await testServer(
            responder: { request, _ in
                return HBResponse(status: .ok, body: .init(asyncSequence: request.body.delayed()))
            },
            httpChannelSetup: server,
            configuration: .init(address: .hostname("127.0.0.1", port: 0)),
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton,
            logger: logger
        ) { (_, port: Int) in
            let bufferSize = 20000
            let body = ByteBuffer(bytes: (0..<bufferSize).map { _ in UInt8.random(in: 0...255) })
            let clientChannel = HTTP1ClientChannel { inbound, outbound in
                try await outbound.writeRequest(
                    .init(
                        "/",
                        method: .get,
                        headers: [.contentLength: bufferSize.description],
                        body: body
                    )
                )
                var inboundIterator = inbound.makeAsyncIterator()
                let response = try await inboundIterator.readResponse()
                XCTAssertEqual(response.body, body)
            }
            switch clientTLSConfiguration {
            case .niossl(let tlsConfiguration):
                let client = try HBClient(
                    TLSClientChannel(clientChannel, tlsConfiguration: tlsConfiguration, serverHostname: testServerName),
                    address: .hostname("127.0.0.1", port: port),
                    eventLoopGroup: eventLoopGroup,
                    logger: logger
                )
                try await client.run()

            #if canImport(Network)
            case .ts(let options):
                let client = try HBClient(
                    clientChannel,
                    address: .hostname("127.0.0.1", port: port),
                    transportServicesTLSOptions: options,
                    eventLoopGroup: eventLoopGroup,
                    logger: logger
                )
                try await client.run()
            #endif
            case .none:
                let client = HBClient(
                    clientChannel,
                    address: .hostname("127.0.0.1", port: port),
                    eventLoopGroup: eventLoopGroup,
                    logger: logger
                )
                try await client.run()
            }
        }
    }

    // MARK: Tests

    func testClient() async throws {
        try await self.testClient(
            server: .http1(),
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton
        )
    }

    func testTLSClient() async throws {
        try await self.testClient(
            server: .tls(.http1(), tlsConfiguration: getServerTLSConfiguration()),
            clientTLSConfiguration: .niossl(getClientTLSConfiguration()),
            eventLoopGroup: MultiThreadedEventLoopGroup.singleton
        )
    }

    #if canImport(Network)
    func testTSClient() async throws {
        try await self.testClient(
            server: .http1(),
            eventLoopGroup: NIOTSEventLoopGroup.singleton
        )
    }

    func testTSNIOSSLClient() async throws {
        try await self.testClient(
            server: .tls(.http1(), tlsConfiguration: getServerTLSConfiguration()),
            clientTLSConfiguration: .niossl(getClientTLSConfiguration()),
            eventLoopGroup: NIOTSEventLoopGroup.singleton
        )
    }

    func testTransportServicesTLSClient() async throws {
        let p12Path = Bundle.module.path(forResource: "client", ofType: "p12")!
        let derPath = Bundle.module.path(forResource: "ca", ofType: "der")!
        let tlsOptions = try XCTUnwrap(TSTLSOptions.options(
            clientIdentity: .p12(filename: p12Path, password: "HBTests"),
            trustRoots: .der(filename: derPath),
            serverName: testServerName
        ))
        try await self.testClient(
            server: .tls(.http1(), tlsConfiguration: getServerTLSConfiguration()),
            clientTLSConfiguration: .ts(tlsOptions),
            eventLoopGroup: NIOTSEventLoopGroup.singleton
        )
    }
    #endif
}

struct HTTP1ClientChannel: HBClientChannel {
    let handler: @Sendable (NIOAsyncChannelInboundStream<HTTPResponsePart>, NIOAsyncChannelOutboundWriter<HTTPRequestPart>) async throws -> Void

    /// Setup child channel for HTTP1
    /// - Parameters:
    ///   - channel: Child channel
    ///   - logger: Logger used during setup
    /// - Returns: Object to process input/output on child channel
    public func setup(channel: Channel, logger: Logger) -> EventLoopFuture<Value> {
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHTTPClientHandlers()
            try channel.pipeline.syncOperations.addHandlers(HTTP1ToHTTPClientCodec())
            return try NIOAsyncChannel(
                wrappingChannelSynchronously: channel,
                configuration: .init()
            )
        }
    }

    /// handle HTTP messages being passed down the channel pipeline
    /// - Parameters:
    ///   - value: Object to process input/output on child channel
    ///   - logger: Logger to use while processing messages
    public func handle(value asyncChannel: NIOAsyncChannel<HTTPResponsePart, HTTPRequestPart>, logger: Logging.Logger) async throws {
        try await asyncChannel.executeThenClose { inbound, outbound in
            try await self.handler(inbound, outbound)
        }
    }
}

struct InvalidHTTPPart: Error {}

extension NIOAsyncChannelInboundStream<HTTPResponsePart>.AsyncIterator {
    mutating func readResponse() async throws -> HBTestClient.Response {
        let headPart = try await self.next()
        guard case .head(let head) = headPart else { throw InvalidHTTPPart() }
        var body = ByteBuffer()
        loop: while let part = try await self.next() {
            switch part {
            case .head:
                throw InvalidHTTPPart()
            case .body(let buffer):
                body.writeImmutableBuffer(buffer)
            case .end:
                break loop
            }
        }
        return .init(head: head, body: body.readableBytes > 0 ? body : nil)
    }
}

extension NIOAsyncChannelOutboundWriter<HTTPRequestPart> {
    func writeRequest(_ request: HBTestClient.Request) async throws {
        try await self.write(.head(request.head))
        if let body = request.body, body.readableBytes > 0 {
            try await self.write(.body(body))
        }
        try await self.write(.end(nil))
    }
}
