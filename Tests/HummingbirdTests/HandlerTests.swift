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
import XCTest

final class HandlerTests: XCTestCase {
    struct DecodeTest<Value: Decodable>: HBRouteHandler, Decodable {
        let value: Value

        init(from request: HBRequest, context: some HBBaseRequestContext) async throws {
            self = try await request.decode(as: Self.self, context: context)
        }

        func handle(context: some HBBaseRequestContext) -> String {
            return "\(Value.self): \(self.value)"
        }
    }

    func testDecodeKeyError() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest<String>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"foo": "bar"}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
                body: body
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let expectation = "Coding key `value` not found."
                XCTAssertEqual(String(buffer: response.body), expectation)
            }
        }
    }

    func testDecodeTypeError() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest<Int>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"value": "bar"}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
                body: body
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let expectation = "Type mismatch for `value` key, expected `Int` type."
                XCTAssertEqual(String(buffer: response.body), expectation)
            }
        }
    }

    func testDecodeValueError() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest<String>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"value": null}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
                body: body
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                #if os(Linux)
                // NOTE: a type mismatch error occures under Linux for null values
                let expectation = "Type mismatch for `value` key, expected `String` type."
                #else
                let expectation = "Value not found for `value` key."
                #endif
                XCTAssertEqual(String(buffer: response.body), expectation)
            }
        }
    }

    func testDecodeInputError() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest<String>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{invalid}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
                body: body
            ) { response in
                XCTAssertEqual(response.status, .badRequest)
                let expectation = "The given data was not valid input."
                XCTAssertEqual(String(buffer: response.body), expectation)
            }
        }
    }

    func testDecode() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest<String>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .post, body: ByteBufferAllocator().buffer(string: #"{"value": "Adam"}"#)) { response in
                XCTAssertEqual(String(buffer: response.body), "String: Adam")
            }
        }
    }

    func testDecodeFail() async throws {
        let router = HBRouter()
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.get("/hello", use: DecodeTest<String>.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/hello", method: .get, body: ByteBufferAllocator().buffer(string: #"{"name2": "Adam"}"#)) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testEmptyRequest() async throws {
        struct ParameterTest: HBRouteHandler {
            let parameter: Int
            init(from request: HBRequest, context: some HBBaseRequestContext) throws {
                self.parameter = try context.parameters.require("test", as: Int.self)
            }

            func handle(context: some HBBaseRequestContext) -> String {
                return "\(self.parameter)"
            }
        }

        let router = HBRouter()
        router.put("/:test", use: ParameterTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/23", method: .put) { response in
                XCTAssertEqual(String(buffer: response.body), "23")
            }
        }
    }
}
