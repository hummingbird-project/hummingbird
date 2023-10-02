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

import Atomics
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

    func testGetRoute() async throws {
        let app = HBApplicationBuilder()
        app.router.get("/hello") { request, context -> EventLoopFuture<ByteBuffer> in
            let buffer = context.allocator.buffer(string: "GET: Hello")
            return context.eventLoop.makeSucceededFuture(buffer)
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "GET: Hello")
            }
        }
    }

    func testHTTPStatusRoute() async throws {
        let app = HBApplicationBuilder()
        app.router.get("/accepted") { _, _ -> HTTPResponseStatus in
            return .accepted
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/accepted", method: .GET) { response in
                XCTAssertEqual(response.status, .accepted)
            }
        }
    }

    func testStandardHeaders() async throws {
        let app = HBApplicationBuilder()
        app.router.get("/hello") { _, _ in
            return "Hello"
        }
        try await app.buildAndTest(.live) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                XCTAssertEqual(response.headers["connection"].first, "keep-alive")
                XCTAssertEqual(response.headers["content-length"].first, "5")
            }
        }
    }

    func testServerHeaders() async throws {
        let app = HBApplicationBuilder(configuration: .init(serverName: "TestServer"))
        app.router.get("/hello") { _, _ in
            return "Hello"
        }
        try await app.buildAndTest(.live) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                XCTAssertEqual(response.headers["server"].first, "TestServer")
            }
        }
    }

    func testPostRoute() async throws {
        let app = HBApplicationBuilder()
        app.router.post("/hello") { _, _ -> String in
            return "POST: Hello"
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .POST) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "POST: Hello")
            }
        }
    }

    func testMultipleMethods() async throws {
        let app = HBApplicationBuilder()
        app.router.post("/hello") { _, _ -> String in
            return "POST"
        }
        app.router.get("/hello") { _, _ -> String in
            return "GET"
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }
            try await client.XCTExecute(uri: "/hello", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "POST")
            }
        }
    }

    func testMultipleGroupMethods() async throws {
        let app = HBApplicationBuilder()
        app.router.group("hello")
            .post { _, _ -> String in
                return "POST"
            }
            .get { _, _ -> String in
                return "GET"
            }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }
            try await client.XCTExecute(uri: "/hello", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "POST")
            }
        }
    }

    func testQueryRoute() async throws {
        let app = HBApplicationBuilder()
        app.router.post("/query") { request, context -> EventLoopFuture<ByteBuffer> in
            let buffer = context.allocator.buffer(string: request.uri.queryParameters["test"].map { String($0) } ?? "")
            return context.eventLoop.makeSucceededFuture(buffer)
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/query?test=test%20data%C3%A9", method: .POST) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "test dataé")
            }
        }
    }

    func testMultipleQueriesRoute() async throws {
        let app = HBApplicationBuilder()
        app.router.post("/add") { request, context -> String in
            return request.uri.queryParameters.getAll("value", as: Int.self).reduce(0,+).description
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/add?value=3&value=45&value=7", method: .POST) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "55")
            }
        }
    }

    func testArray() async throws {
        let app = HBApplicationBuilder()
        app.router.get("array") { _, _ -> [String] in
            return ["yes", "no"]
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/array", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
            }
        }
    }

    func testEventLoopFutureArray() async throws {
        let app = HBApplicationBuilder()
        app.router.patch("array") { request, context -> EventLoopFuture<[String]> in
            return context.success(["yes", "no"])
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/array", method: .PATCH) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
            }
        }
    }

    func testResponseBody() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/echo-body")
            .post { request, context -> HBResponse in
                let body: HBResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
                return .init(status: .ok, headers: [:], body: body)
            }
        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 1_140_000)
            try await client.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreaming() async throws {
        let app = HBApplicationBuilder()
        app.router.post("streaming", options: .streamBody) { request, context -> HBResponse in
            guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
            struct RequestStreamer: HBResponseBodyStreamer {
                let stream: HBStreamerProtocol

                func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
                    return self.stream.consume(on: eventLoop).map { chunk in
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
        app.router.post("size", options: .streamBody) { request, context -> EventLoopFuture<String> in
            guard let stream = request.body.stream else {
                return context.failure(.badRequest)
            }
            let size = ManagedAtomic(0)
            return stream.consumeAll(on: context.eventLoop) { buffer in
                size.wrappingIncrement(by: buffer.readableBytes, ordering: .relaxed)
                return context.success(())
            }
            .map { _ in size.load(ordering: .relaxed).description }
        }

        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 640_001)
            try await client.XCTExecute(uri: "/streaming", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/streaming", method: .POST) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
            try await client.XCTExecute(uri: "/size", method: .POST, body: buffer) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "640001")
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreamingSmallBuffer() async throws {
        let app = HBApplicationBuilder()
        app.router.post("streaming", options: .streamBody) { request, context -> HBResponse in
            guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
            struct RequestStreamer: HBResponseBodyStreamer {
                let stream: HBStreamerProtocol

                func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
                    return self.stream.consume(on: eventLoop).map { chunk in
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
        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 64)
            try await client.XCTExecute(uri: "/streaming", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/streaming", method: .POST) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testCollateBody() async throws {
        struct CollateMiddleware: HBMiddleware {
            func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return context.collateBody(of: request).flatMap { request in
                    context.logger.info("Buffer size: \(request.body.buffer!.readableBytes)")
                    return next.respond(to: request, context: context)
                }
            }
        }
        let app = HBApplicationBuilder()
        app.middleware.add(CollateMiddleware())
        app.router.put("/hello") { _, _ -> HTTPResponseStatus in
            return .ok
        }
        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 512_000)
            try await client.XCTExecute(uri: "/hello", method: .PUT, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testOptional() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/echo-body")
            .post { request, _ -> ByteBuffer? in
                return request.body.buffer
            }
        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 64)
            try await client.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/echo-body", method: .POST) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testELFOptional() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/echo-body")
            .post { request, context -> EventLoopFuture<ByteBuffer?> in
                return context.success(request.body.buffer)
            }
        try await app.buildAndTest(.router) { client in

            let buffer = self.randomBuffer(size: 64)
            try await client.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/echo-body", method: .POST) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testOptionalCodable() async throws {
        struct Name: HBResponseCodable {
            let first: String
            let last: String
        }
        let app = HBApplicationBuilder()
        app.router
            .group("/name")
            .patch { _, _ -> Name? in
                return Name(first: "john", last: "smith")
            }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/name", method: .PATCH) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), #"Name(first: "john", last: "smith")"#)
            }
        }
    }

    func testEditResponse() async throws {
        let app = HBApplicationBuilder()
        app.router.delete("/hello", options: .editResponse) { request, _ -> String in
            request.response.headers.add(name: "test", value: "value")
            request.response.headers.replaceOrAdd(name: "content-type", value: "application/json")
            request.response.status = .imATeapot
            return "Hello"
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .DELETE) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .imATeapot)
                XCTAssertEqual(response.headers["test"].first, "value")
                XCTAssertEqual(response.headers["content-type"].count, 1)
                XCTAssertEqual(response.headers["content-type"].first, "application/json")
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    func testEditResponseFuture() async throws {
        let app = HBApplicationBuilder()
        app.router.delete("/hello", options: .editResponse) { request, context -> EventLoopFuture<String> in
            request.response.headers.add(name: "test", value: "value")
            request.response.headers.replaceOrAdd(name: "content-type", value: "application/json")
            request.response.status = .imATeapot
            return context.success("Hello")
        }
        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .DELETE) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .imATeapot)
                XCTAssertEqual(response.headers["test"].first, "value")
                XCTAssertEqual(response.headers["content-type"].count, 1)
                XCTAssertEqual(response.headers["content-type"].first, "application/json")
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    func testMaxUploadSize() async throws {
        let app = HBApplicationBuilder(configuration: .init(maxUploadSize: 64 * 1024))
        app.router.post("upload") { _, _ in
            "ok"
        }
        app.router.post("stream", options: .streamBody) { _, _ in
            "ok"
        }
        try await app.buildAndTest(.live) { client in
            let buffer = self.randomBuffer(size: 128 * 1024)
            // check non streamed route throws an error
            try await client.XCTExecute(uri: "/upload", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .payloadTooLarge)
            }
            // check streamed route doesn't
            try await client.XCTExecute(uri: "/stream", method: .POST, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testRemoteAddress() async throws {
        let app = HBApplicationBuilder()
        app.router.get("/") { request, context -> String in
            switch context.remoteAddress {
            case .v4(let address):
                return String(describing: address.host)
            case .v6(let address):
                return String(describing: address.host)
            default:
                throw HBHTTPError(.internalServerError)
            }
        }
        try await app.buildAndTest(.live) { client in

            try await client.XCTExecute(uri: "/", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                let address = String(buffer: body)
                XCTAssert(address == "127.0.0.1" || address == "::1")
            }
        }
    }
}
