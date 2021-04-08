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
import HummingbirdFoundation
import HummingbirdXCT
import NIOHTTP1
import XCTest

final class HandlerTests: XCTestCase {
    func testDecode() {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> String {
                return "Hello \(self.name)"
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .POST, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }

    func testDecodeFutureResponse() {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> EventLoopFuture<String> {
                return request.success("Hello \(self.name)")
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.put("/hello", use: DecodeTest.self)

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .PUT, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }

    func testDecodeFail() {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> HTTPResponseStatus {
                return .ok
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.get("/hello", use: DecodeTest.self)

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET, body: ByteBufferAllocator().buffer(string: #"{"name2": "Adam"}"#)) { response in
            XCTAssertEqual(response.status, .badRequest)
        }
    }

    func testEmptyRequest() {
        struct ParameterTest: HBRouteHandler {
            let parameter: Int
            init(from request: HBRequest) throws {
                self.parameter = try request.parameters.require("test", as: Int.self)
            }

            func handle(request: HBRequest) -> String {
                return "\(self.parameter)"
            }
        }

        let app = HBApplication(testing: .embedded)
        app.router.put("/:test", use: ParameterTest.self)

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/23", method: .PUT) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "23")
        }
    }
}
