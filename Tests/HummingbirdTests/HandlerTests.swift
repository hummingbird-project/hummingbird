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
    func testDecodeKeyError() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"foo": "bar"}"#)

            try await client.XCTExecute(
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
    }

    func testDecodeTypeError() async throws {
        struct DecodeTest: HBRequestDecodable {
            let value: Int

            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "Value: \(self.value)"
            }
        }

        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"value": "bar"}"#)

            try await client.XCTExecute(
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
    }

    func testDecodeValueError() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"name": null}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .POST,
                body: body
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let body = try XCTUnwrap(response.body)
                #if os(Linux)
                // NOTE: a type mismatch error occures under Linux for null values
                let expectation = "Type mismatch for `name` key, expected `String` type."
                #else
                let expectation = "Value not found for `name` key."
                #endif
                XCTAssertEqual(String(buffer: body), expectation)
            }
        }
    }

    func testDecodeInputError() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{invalid}"#)

            try await client.XCTExecute(
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
    }

    func testDecode() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }
        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.post("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .POST, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Hello Adam")
            }
        }
    }

    func testDecodeFutureResponse() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest, context: HBRequestContext) -> EventLoopFuture<String> {
                return request.success("Hello \(self.name)")
            }
        }
        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.put("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .PUT, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Hello Adam")
            }
        }
    }

    func testDecodeFail() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            
            func handle(request: HBRequest, context: HBRequestContext) -> HTTPResponseStatus {
                return .ok
            }
        }
        let app = HBApplicationBuilder()
        app.decoder = JSONDecoder()
        app.router.get("/hello", use: DecodeTest.self)

        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .GET, body: ByteBufferAllocator().buffer(string: #"{"name2": "Adam"}"#)) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testEmptyRequest() async throws {
        struct ParameterTest: HBRouteHandler {
            let parameter: Int
            init(from request: HBRequest, context: HBRequestContext) throws {
                self.parameter = try request.parameters.require("test", as: Int.self)
            }

            func handle(request: HBRequest, context: HBRequestContext) -> String {
                return "\(self.parameter)"
            }
        }

        let app = HBApplicationBuilder()
        app.router.put("/:test", use: ParameterTest.self)

        try await app.buildAndTest(.router) { client in

            try await client.XCTExecute(uri: "/23", method: .PUT) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "23")
            }
        }
    }
}
