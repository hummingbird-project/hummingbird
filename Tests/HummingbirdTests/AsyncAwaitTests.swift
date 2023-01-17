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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AsyncAwaitTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func getBuffer(request: HBRequest) async -> ByteBuffer {
        return request.allocator.buffer(string: "Async Hello")
    }

    func testAsyncRoute() throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let app = HBApplication(testing: .asyncTest)
        app.router.get("/hello") { request -> ByteBuffer in
            return await self.getBuffer(request: request)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "Async Hello")
        }
    }

    func testAsyncMiddleware() throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        struct AsyncTestMiddleware: HBAsyncMiddleware {
            func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
                var response = try await next.respond(to: request)
                response.headers.add(name: "async", value: "true")
                return response
            }
        }
        let app = HBApplication(testing: .asyncTest)
        app.middleware.add(AsyncTestMiddleware())
        app.router.get("/hello") { _ -> String in
            "hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["async"].first, "true")
        }
    }

    func testAsyncRouteHandler() throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        struct AsyncTest: HBAsyncRouteHandler {
            let name: String
            init(from request: HBRequest) throws {
                self.name = try request.parameters.require("name")
            }

            func handle(request: HBRequest) async throws -> String {
                return try await request.success("Hello \(self.name)").get()
            }
        }
        let app = HBApplication(testing: .asyncTest)
        app.router.post("/hello/:name", use: AsyncTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello/Adam", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }

    /// Test streaming of requests via AsyncSequence
    func testStreaming() throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let app = HBApplication(testing: .asyncTest)
        app.router.post("size", options: .streamBody) { request -> String in
            guard let stream = request.body.stream else {
                throw HBHTTPError(.badRequest)
            }
            var size = 0
            for try await buffer in stream.sequence {
                size += buffer.readableBytes
            }
            return size.description
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 530_001)
        try app.XCTExecute(uri: "/size", method: .POST, body: buffer) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "530001")
        }
    }
}

#endif // compiler(>=5.5) && canImport(_Concurrency)
