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

#if compiler(>=5.5) && $AsyncAwait

import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

@available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, *)
final class AsyncTests: XCTestCase {
    func testAsyncRoute() {
        let app = HBApplication(testing: .live)
        app.router.get("/hello") { request -> ByteBuffer in
            let buffer = request.allocator.buffer(string: "Async Hello")
            return try await request.eventLoop.makeSucceededFuture(buffer).get()
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "Async Hello")
        }
    }

    func testAsyncMiddleware() {
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
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["async"].first, "true")
        }
    }

    func testAsyncRouteHandler() {
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

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello/Adam", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }

    }
}

#endif // compiler(>=5.5) && $AsyncAwait
