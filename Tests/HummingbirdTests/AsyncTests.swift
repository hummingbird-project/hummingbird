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

#if compiler(>=5.5)

import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class AsyncTests: XCTestCase {
    func getBuffer(request: HBRequest) async -> ByteBuffer {
        return request.allocator.buffer(string: "Async Hello")
    }

    func testAsyncRoute() throws {
        let app = HBApplication(testing: .live)
        app.router.get("/hello") { request -> ByteBuffer in
            return await self.getBuffer(request: request)
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "Async Hello")
        }
    }

    func testAsyncMiddleware() throws {
        struct AsyncTestMiddleware: HBAsyncMiddleware {
            func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
                let response = try await next.respond(to: request)
                response.headers.add(name: "async", value: "true")
                return response
            }
        }
        let app = HBApplication(testing: .live)
        app.middleware.add(AsyncTestMiddleware())
        app.router.get("/hello") { _ -> String in
            "hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["async"].first, "true")
        }
    }

    func testAsyncRouteHandler() throws {
        struct AsyncTest: HBAsyncRouteHandler {
            let name: String
            init(from request: HBRequest) throws {
                self.name = try request.parameters.require("name")
            }

            func handle(request: HBRequest) async throws -> String {
                return try await request.success("Hello \(self.name)").get()
            }
        }
        let app = HBApplication(testing: .live)
        app.router.post("/hello/:name", use: AsyncTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello/Adam", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }
}

#endif // compiler(>=5.5)
