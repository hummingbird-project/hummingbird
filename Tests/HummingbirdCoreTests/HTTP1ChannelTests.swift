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
import Logging
import NIOCore
import NIOEmbedded
import NIOHTTP1
import XCTest

final class HTTP1ChannelTests: XCTestCase {
    func testHTTP1Channel(
        _ test: (NIOAsyncTestingChannel) async throws -> Void,
        responder: @escaping HTTPChannelHandler.Responder = { (request: Request, writer: consuming ResponseWriter, channel: Channel) in
            let body = try await request.body.collect(upTo: .max)
            try await writer.writeResponse(
                .init(
                    status: .ok,
                    headerFields: [.test: "\(body.readableBytes)", .contentLength: "0"]
                )
            )
        }
    ) async throws {
        let channel = NIOAsyncTestingChannel()
        let logger = Logger(label: "HTTP1Channel")

        let http1Channel = HTTP1Channel(responder: responder)
        let value = try await channel.eventLoop.flatSubmit {
            http1Channel.setup(channel: channel, logger: logger)
        }.get()

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await http1Channel.handle(value: value, logger: logger)
            }
            try await test(channel)
            try await group.waitForAll()
        }
    }

    func testHTTPParserError() async throws {
        try await testHTTP1Channel { channel in
            channel.pipeline.fireErrorCaught(HTTPParserError.unknown)
            let outbound = try await channel.waitForOutboundWrite(as: ByteBuffer.self)
            XCTAssertEqual(
                String(buffer: outbound),
                "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
            )
        }
    }

    func testHTTPParserErrorAfterHeader() async throws {
        try await testHTTP1Channel { channel in
            try await channel.writeInbound(ByteBuffer(string: "GET / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 16\r\n\r\n"))
            channel.pipeline.fireErrorCaught(HTTPParserError.unknown)
            let outbound = try await channel.waitForOutboundWrite(as: ByteBuffer.self)
            XCTAssertEqual(
                String(buffer: outbound),
                "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
            )
        }
    }

    func testHTTPParserErrorAfterSuccessfulResponse() async throws {
        try await testHTTP1Channel { channel in
            try await channel.writeInbound(ByteBuffer(string: "GET / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 0\r\n\r\n"))
            var outbound = try await channel.waitForOutboundWrite(as: ByteBuffer.self)
            XCTAssertEqual(
                String(buffer: outbound),
                "HTTP/1.1 200 OK\r\ntest: 0\r\nContent-Length: 0\r\n\r\n"
            )
            channel.pipeline.fireErrorCaught(HTTPParserError.unknown)
            outbound = try await channel.waitForOutboundWrite(as: ByteBuffer.self)
            XCTAssertEqual(
                String(buffer: outbound),
                "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
            )
        }
    }

    func testHTTPParserErrorInvalidMethod() async throws {
        try await testHTTP1Channel { channel in
            do {
                try await channel.writeInbound(ByteBuffer(string: "INVALID / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 0\r\n\r\n"))
            } catch HTTPParserError.invalidMethod {}
            let outbound = try await channel.waitForOutboundWrite(as: ByteBuffer.self)
            XCTAssertEqual(
                String(buffer: outbound),
                "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n"
            )
        }
    }
}

/// HTTPField used during tests
extension HTTPField.Name {
    static let test = Self("test")!
}
