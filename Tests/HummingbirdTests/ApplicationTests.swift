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

import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

final class ApplicationTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testGetRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "GET: Hello")
        }
    }

    func testHTTPStatusRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("/accepted") { _ -> HTTPResponseStatus in
            return .accepted
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/accepted", method: .GET) { response in
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testStandardHeaders() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { _ in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["connection"].first, "keep-alive")
            XCTAssertEqual(response.headers["content-length"].first, "5")
        }
    }

    func testServerHeaders() throws {
        let app = HBApplication(testing: .embedded, configuration: .init(serverName: "TestServer"))
        app.router.get("/hello") { _ in
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["server"].first, "TestServer")
        }
    }

    func testPostRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.post("/hello") { _ -> String in
            return "POST: Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .POST) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "POST: Hello")
        }
    }

    func testMultipleMethods() throws {
        let app = HBApplication(testing: .embedded)
        app.router.post("/hello") { _ -> String in
            return "POST"
        }
        app.router.get("/hello") { _ -> String in
            return "GET"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }
        app.XCTExecute(uri: "/hello", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "POST")
        }
    }

    func testMultipleGroupMethods() throws {
        let app = HBApplication(testing: .embedded)
        app.router.group("hello")
            .post { _ -> String in
                return "POST"
            }
            .get { _ -> String in
                return "GET"
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }
        app.XCTExecute(uri: "/hello", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "POST")
        }
    }

    func testQueryRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.post("/query") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: request.uri.queryParameters["test"].map { String($0) } ?? "")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/query?test=test%20data%C3%A9", method: .POST) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "test dataé")
        }
    }

    func testArray() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("array") { _ -> [String] in
            return ["yes", "no"]
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/array", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
        }
    }

    func testEventLoopFutureArray() throws {
        let app = HBApplication(testing: .embedded)
        app.router.patch("array") { request -> EventLoopFuture<[String]> in
            return request.success(["yes", "no"])
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/array", method: .PATCH) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
        }
    }

    func testResponseBody() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/echo-body")
            .post { request -> HBResponse in
                let body: HBResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
                return .init(status: .ok, headers: [:], body: body)
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 1_140_000)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreaming() throws {
        let app = HBApplication(testing: .embedded)
        app.router.post("streaming", options: .streamBody) { request -> HBResponse in
            guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
            struct RequestStreamer: HBResponseBodyStreamer {
                let stream: HBStreamerProtocol

                func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
                    return stream.consume(on: eventLoop).map { chunk in
                        switch chunk {
                        case .byteBuffer(let buffer):
                            return .byteBuffer(buffer)
                        case .end:
                            return .end
                        }
                    }
                }
            }
            return HBResponse(status: .ok, headers: [:], body: .stream(RequestStreamer(stream: stream)))
        }
        app.router.post("size", options: .streamBody) { request -> EventLoopFuture<String> in
            guard let stream = request.body.stream else {
                return request.failure(.badRequest)
            }
            var size = 0
            return stream.consumeAll(on: request.eventLoop) { buffer in
                size += buffer.readableBytes
                return request.success(())
            }
            .map { _ in size.description }
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 640_001)
        app.XCTExecute(uri: "/streaming", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body, buffer)
        }
        app.XCTExecute(uri: "/streaming", method: .POST) { response in
            XCTAssertEqual(response.status, .badRequest)
        }
        app.XCTExecute(uri: "/size", method: .POST, body: buffer) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "640001")
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreamingSmallBuffer() throws {
        let app = HBApplication(testing: .embedded)
        app.router.post("streaming", options: .streamBody) { request -> HBResponse in
            guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
            struct RequestStreamer: HBResponseBodyStreamer {
                let stream: HBStreamerProtocol

                func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
                    return stream.consume(on: eventLoop).map { chunk in
                        switch chunk {
                        case .byteBuffer(let buffer):
                            return .byteBuffer(buffer)
                        case .end:
                            return .end
                        }
                    }
                }
            }
            return HBResponse(status: .ok, headers: [:], body: .stream(RequestStreamer(stream: stream)))
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 64)
        app.XCTExecute(uri: "/streaming", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body, buffer)
        }
        app.XCTExecute(uri: "/streaming", method: .POST) { response in
            XCTAssertEqual(response.status, .badRequest)
        }
    }

    func testOptional() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/echo-body")
            .post { request -> ByteBuffer? in
                return request.body.buffer
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 64)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body, buffer)
        }
        app.XCTExecute(uri: "/echo-body", method: .POST) { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }

    func testELFOptional() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/echo-body")
            .post { request -> EventLoopFuture<ByteBuffer?> in
                return request.success(request.body.buffer)
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 64)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body, buffer)
        }
        app.XCTExecute(uri: "/echo-body", method: .POST) { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }

    func testOptionalCodable() throws {
        struct Name: HBResponseCodable {
            let first: String
            let last: String
        }
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/name")
            .patch { _ -> Name? in
                return Name(first: "john", last: "smith")
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/name", method: .PATCH) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), #"Name(first: "john", last: "smith")"#)
        }
    }

    func testEditResponse() throws {
        let app = HBApplication(testing: .embedded)
        app.router.delete("/hello", options: .editResponse) { request -> String in
            request.response.headers.add(name: "test", value: "value")
            request.response.headers.replaceOrAdd(name: "content-type", value: "application/json")
            request.response.status = .imATeapot
            return "Hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .DELETE) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .imATeapot)
            XCTAssertEqual(response.headers["test"].first, "value")
            XCTAssertEqual(response.headers["content-type"].count, 1)
            XCTAssertEqual(response.headers["content-type"].first, "application/json")
            XCTAssertEqual(string, "Hello")
        }
    }

    func testEditResponseFuture() throws {
        let app = HBApplication(testing: .embedded)
        app.router.delete("/hello", options: .editResponse) { request -> EventLoopFuture<String> in
            request.response.headers.add(name: "test", value: "value")
            request.response.headers.replaceOrAdd(name: "content-type", value: "application/json")
            request.response.status = .imATeapot
            return request.success("Hello")
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .DELETE) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .imATeapot)
            XCTAssertEqual(response.headers["test"].first, "value")
            XCTAssertEqual(response.headers["content-type"].count, 1)
            XCTAssertEqual(response.headers["content-type"].first, "application/json")
            XCTAssertEqual(string, "Hello")
        }
    }

    func testRemoteAddress() throws {
        let app = HBApplication(testing: .live)
        app.router.get("/") { request -> String in
            switch request.remoteAddress {
            case .v4(let address):
                return String(describing: address.host)
            case .v6(let address):
                return String(describing: address.host)
            default:
                throw HBHTTPError(.internalServerError)
            }
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            let address = String(buffer: body)
            XCTAssert(address == "127.0.0.1" || address == "::1")
        }
    }
}
