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
    
    func testDecodeKeyError() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest) -> String {
                return "Hello \(self.name)"
            }
        }
        
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        let body = ByteBufferAllocator().buffer(string: #"{"foo": "bar"}"#)
        
        try app.XCTExecute(
            uri: "/hello",
            method: .POST,
            body: body
        ) { response in
            XCTAssertEqual(response.status, .badRequest)
            let body = try XCTUnwrap(response.body)
            let expectation = "Coding key `name` not found."
            XCTAssertEqual(String(buffer: body), expectation)
        }
    }
    
    func testDecodeTypeError() throws {
        struct DecodeTest: HBRequestDecodable {
            let value: Int

            func handle(request: HBRequest) -> String {
                return "Value: \(self.value)"
            }
        }
        
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        let body = ByteBufferAllocator().buffer(string: #"{"value": "bar"}"#)
        
        try app.XCTExecute(
            uri: "/hello",
            method: .POST,
            body: body
        ) { response in
            XCTAssertEqual(response.status, .badRequest)
            let body = try XCTUnwrap(response.body)
            let expectation = "Type mismatch for `value` key, expected `Int` type."
            XCTAssertEqual(String(buffer: body), expectation)
        }
    }
    
    func testDecodeValueError() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest) -> String {
                return "Hello \(self.name)"
            }
        }
        
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        let body = ByteBufferAllocator().buffer(string: #"{"name": null}"#)
        
        try app.XCTExecute(
            uri: "/hello",
            method: .POST,
            body: body
        ) { response in
            XCTAssertEqual(response.status, .badRequest)
            let body = try XCTUnwrap(response.body)
            let expectation = "Value not found for `name` key."
            XCTAssertEqual(String(buffer: body), expectation)
        }
    }
    
    func testDecodeInputError() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest) -> String {
                return "Hello \(self.name)"
            }
        }
        
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        let body = ByteBufferAllocator().buffer(string: #"{invalid}"#)
        
        try app.XCTExecute(
            uri: "/hello",
            method: .POST,
            body: body
        ) { response in
            XCTAssertEqual(response.status, .badRequest)
            let body = try XCTUnwrap(response.body)
            let expectation = "The given data was not valid input."
            XCTAssertEqual(String(buffer: body), expectation)
        }
    }
    
    func testDecode() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> String {
                return "Hello \(self.name)"
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .POST, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }

    func testDecodeFutureResponse() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> EventLoopFuture<String> {
                return request.success("Hello \(self.name)")
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.put("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .PUT, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Hello Adam")
        }
    }

    func testDecodeFail() throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest) -> HTTPResponseStatus {
                return .ok
            }
        }
        let app = HBApplication(testing: .embedded)
        app.decoder = JSONDecoder()
        app.router.get("/hello", use: DecodeTest.self)

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/hello", method: .GET, body: ByteBufferAllocator().buffer(string: #"{"name2": "Adam"}"#)) { response in
            XCTAssertEqual(response.status, .badRequest)
        }
    }

    func testEmptyRequest() throws {
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

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/23", method: .PUT) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "23")
        }
    }
}
