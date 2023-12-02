//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
import HTTPTypes
import Hummingbird
import HummingbirdCore
import HummingbirdXCT
import Logging
import NIOCore
import XCTest

final class ApplicationTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testGetRoute() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("/hello") { _, context -> ByteBuffer in
            return context.allocator.buffer(string: "GET: Hello")
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "GET: Hello")
            }
        }
    }

    func testHTTPStatusRoute() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("/accepted") { _, _ -> HTTPResponse.Status in
            return .accepted
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/accepted", method: .get) { response in
                XCTAssertEqual(response.status, .accepted)
            }
        }
    }

    func testStandardHeaders() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("/hello") { _, _ in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.live) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.contentLength], "5")
                XCTAssertNotNil(response.headers[.date])
            }
        }
    }

    func testServerHeaders() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("/hello") { _, _ in
            return "Hello"
        }
        let app = HBApplication(responder: router.buildResponder(), configuration: .init(serverName: "TestServer"))
        try await app.test(.live) { client in
            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.headers[.server], "TestServer")
            }
        }
    }

    func testPostRoute() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("/hello") { _, _ -> String in
            return "POST: Hello"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .post) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "POST: Hello")
            }
        }
    }

    func testMultipleMethods() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("/hello") { _, _ -> String in
            return "POST"
        }
        router.get("/hello") { _, _ -> String in
            return "GET"
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }
            try await client.XCTExecute(uri: "/hello", method: .post) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "POST")
            }
        }
    }

    func testMultipleGroupMethods() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.group("hello")
            .post { _, _ -> String in
                return "POST"
            }
            .get { _, _ -> String in
                return "GET"
            }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }
            try await client.XCTExecute(uri: "/hello", method: .post) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "POST")
            }
        }
    }

    func testQueryRoute() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("/query") { request, context -> ByteBuffer in
            return context.allocator.buffer(string: request.uri.queryParameters["test"].map { String($0) } ?? "")
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/query?test=test%20data%C3%A9", method: .post) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "test dataé")
            }
        }
    }

    func testMultipleQueriesRoute() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("/add") { request, _ -> String in
            return request.uri.queryParameters.getAll("value", as: Int.self).reduce(0,+).description
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/add?value=3&value=45&value=7", method: .post) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "55")
            }
        }
    }

    func testArray() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("array") { _, _ -> [String] in
            return ["yes", "no"]
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/array", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
            }
        }
    }

    func testResponseBody() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router
            .group("/echo-body")
            .post { request, _ -> HBResponse in
                let buffer = try await request.body.collect(upTo: .max)
                return .init(status: .ok, headers: [:], body: .init(byteBuffer: buffer))
            }
        let app = HBApplication(responder: router.buildResponder(), configuration: .init(maxUploadSize: 2 * 1024 * 1024))
        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 1_140_000)
            try await client.XCTExecute(uri: "/echo-body", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreaming() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("streaming") { request, _ -> HBResponse in
            return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
        }
        router.post("size") { request, _ -> String in
            var size = 0
            for try await buffer in request.body {
                size += buffer.readableBytes
            }
            return size.description
        }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 640_001)
            try await client.XCTExecute(uri: "/streaming", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/streaming", method: .post) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, ByteBuffer())
            }
            try await client.XCTExecute(uri: "/size", method: .post, body: buffer) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "640001")
            }
        }
    }

    /// Test streaming of requests and streaming of responses by streaming the request body into a response streamer
    func testStreamingSmallBuffer() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.post("streaming") { request, _ -> HBResponse in
            return HBResponse(status: .ok, body: .init(asyncSequence: request.body))
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 64)
            try await client.XCTExecute(uri: "/streaming", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/streaming", method: .post) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, ByteBuffer())
            }
        }
    }

    func testCollateBody() async throws {
        struct CollateMiddleware<Context: HBBaseRequestContext>: HBMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var request = request
                request.body = try await request.body.collate(maxSize: context.applicationContext.configuration.maxUploadSize)
                return try await next.respond(to: request, context: context)
            }
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(CollateMiddleware())
        router.put("/hello") { request, _ -> String in
            guard case .byteBuffer(let buffer) = request.body else { throw HBHTTPError(.internalServerError) }
            return buffer.readableBytes.description
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 512_000)
            try await client.XCTExecute(uri: "/hello", method: .put, body: buffer) { response in
                XCTAssertEqual(response.body.map { String(buffer: $0) }, "512000")
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testOptional() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router
            .group("/echo-body")
            .post { request, _ -> ByteBuffer? in
                let buffer = try await request.body.collect(upTo: .max)
                return buffer.readableBytes > 0 ? buffer : nil
            }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            let buffer = self.randomBuffer(size: 64)
            try await client.XCTExecute(uri: "/echo-body", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
            try await client.XCTExecute(uri: "/echo-body", method: .post) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testOptionalCodable() async throws {
        struct Name: HBResponseCodable {
            let first: String
            let last: String
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router
            .group("/name")
            .patch { _, _ -> Name? in
                return Name(first: "john", last: "smith")
            }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/name", method: .patch) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), #"Name(first: "john", last: "smith")"#)
            }
        }
    }

    func testTypedResponse() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.delete("/hello") { _, _ in
            return HBEditedResponse(
                status: .preconditionRequired,
                headers: [.test: "value", .contentType: "application/json"],
                response: "Hello"
            )
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .delete) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .preconditionRequired)
                XCTAssertEqual(response.headers[.test], "value")
                XCTAssertEqual(response.headers[.contentType], "application/json")
                XCTAssertEqual(string, "Hello")
            }
        }
    }

    func testCodableTypedResponse() async throws {
        struct Result: HBResponseEncodable {
            let value: String
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.patch("/hello") { _, _ in
            return HBEditedResponse(
                status: .multipleChoices,
                headers: [.test: "value", .contentType: "application/json"],
                response: Result(value: "true")
            )
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .patch) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .multipleChoices)
                XCTAssertEqual(response.headers[.test], "value")
                XCTAssertEqual(response.headers[.contentType], "application/json")
                XCTAssertEqual(string, #"{"value":"true"}"#)
            }
        }
    }

    func testMaxUploadSize() async throws {
        let router = HBRouter()
        router.post("upload") { request, context in
            _ = try await request.body.collate(maxSize: context.applicationContext.configuration.maxUploadSize)
            return "ok"
        }
        router.post("stream") { _, _ in
            "ok"
        }
        let app = HBApplication(responder: router.buildResponder(), configuration: .init(maxUploadSize: 64 * 1024))
        try await app.test(.live) { client in
            let buffer = self.randomBuffer(size: 128 * 1024)
            // check non streamed route throws an error
            try await client.XCTExecute(uri: "/upload", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .contentTooLarge)
            }
            // check streamed route doesn't
            try await client.XCTExecute(uri: "/stream", method: .post, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testRemoteAddress() async throws {
        /// Implementation of a basic request context that supports everything the Hummingbird library needs
        struct HBSocketAddressRequestContext: HBRequestContext {
            /// core context
            var coreContext: HBCoreRequestContext
            // socket address
            let remoteAddress: SocketAddress?

            public init(
                applicationContext: HBApplicationContext,
                channel: Channel,
                logger: Logger
            ) {
                self.coreContext = .init(applicationContext: applicationContext, eventLoop: channel.eventLoop, allocator: channel.allocator, logger: logger)
                self.remoteAddress = channel.remoteAddress
            }
        }
        let router = HBRouter(context: HBSocketAddressRequestContext.self)
        router.get("/") { _, context -> String in
            switch context.remoteAddress {
            case .v4(let address):
                return String(describing: address.host)
            case .v6(let address):
                return String(describing: address.host)
            default:
                throw HBHTTPError(.internalServerError)
            }
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.live) { client in

            try await client.XCTExecute(uri: "/", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                let address = String(buffer: body)
                XCTAssert(address == "127.0.0.1" || address == "::1")
            }
        }
    }
}

extension HTTPField.Name {
    static let test = Self("Test")!
}
