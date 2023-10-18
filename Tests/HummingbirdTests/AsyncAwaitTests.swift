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
import HummingbirdCore
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

    func getBuffer(request: HBRequest, context: HBRequestContext) async -> ByteBuffer {
        return context.allocator.buffer(string: "Async Hello")
    }

    func testAsyncRoute() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.get("/hello") { request, context -> ByteBuffer in
            return await self.getBuffer(request: request, context: context)
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "Async Hello")
            }
        }
    }

    func testAsyncRouterGroup() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.group("test").get("/hello") { request, context -> ByteBuffer in
            return await self.getBuffer(request: request, context: context)
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test/hello", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "Async Hello")
            }
        }
    }

    func testAsyncMiddleware() async throws {
        struct AsyncTestMiddleware<Context: HBRequestContext>: HBAsyncMiddleware {
            func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
                var response = try await next.respond(to: request, context: context)
                response.headers.add(name: "async", value: "true")
                return response
            }
        }
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.middleware.add(AsyncTestMiddleware())
        app.router.get("/hello") { _, _ -> String in
            "hello"
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET) { response in
                XCTAssertEqual(response.headers["async"].first, "true")
            }
        }
    }

    func testAsyncRouteHandler() async throws {
        struct AsyncTest: HBAsyncRouteHandler {
            let name: String
            init(from request: HBRequest, context: HBRequestContext) throws {
                self.name = try context.parameters.require("name")
            }

            func handle(request: HBRequest, context: HBRequestContext) async throws -> String {
                return try await context.success("Hello \(self.name)").get()
            }
        }
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.post("/hello/:name", use: AsyncTest.self)

        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/hello/Adam", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Hello Adam")
            }
        }
    }

    func testCollatingRequestBody() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.patch("size") { request, _ -> String in
            guard let body = request.body.buffer else {
                throw HBHTTPError(.badRequest)
            }
            // force route to be async
            try await Task.sleep(nanoseconds: 1)
            return body.readableBytes.description
        }

        try await app.buildAndTest(.router) { client in
            let buffer = self.randomBuffer(size: 530_001)
            try await client.XCTExecute(uri: "/size", method: .PATCH, body: buffer) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "530001")
            }
        }
    }

    /// Test streaming of requests via AsyncSequence
    func testStreaming() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.post("size", options: .streamBody) { request, _ -> String in
            guard let stream = request.body.stream else {
                throw HBHTTPError(.badRequest)
            }
            var size = 0
            for try await buffer in stream.sequence {
                size += buffer.readableBytes
            }
            return size.description
        }

        try await app.buildAndTest(.router) { client in
            let buffer = self.randomBuffer(size: 530_001)
            try await client.XCTExecute(uri: "/size", method: .POST, body: buffer) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "530001")
            }
        }
    }

    /// Test streaming of response via AsyncSequence
    func testResponseAsyncSequence() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.get("buffer", options: .streamBody) { request, _ -> HBRequestBodyStreamerSequence.ResponseGenerator in
            guard let stream = request.body.stream else { throw HBHTTPError(.badRequest) }
            return stream.sequence.responseGenerator
        }

        try await app.buildAndTest(.router) { client in
            let buffer = self.randomBuffer(size: 530_001)
            try await client.XCTExecute(uri: "/buffer", method: .GET, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    /// Test streaming of response via AsyncSequence
    func testResponseAsyncStream() async throws {
        let app = HBApplicationBuilder(context: HBTestRouterContext.self)
        app.router.get("alphabet") { _, _ in
            AsyncStream<ByteBuffer> { cont in
                let alphabet = "abcdefghijklmnopqrstuvwxyz"
                var index = alphabet.startIndex
                while index != alphabet.endIndex {
                    let nextIndex = alphabet.index(after: index)
                    let buffer = ByteBufferAllocator().buffer(substring: alphabet[index..<nextIndex])
                    cont.yield(buffer)
                    index = nextIndex
                }
                cont.finish()
            }
        }

        try await app.buildAndTest(.router) { client in
            let buffer = self.randomBuffer(size: 530_001)
            try await client.XCTExecute(uri: "/alphabet", method: .GET, body: buffer) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: body), "abcdefghijklmnopqrstuvwxyz")
            }
        }
    }
}
