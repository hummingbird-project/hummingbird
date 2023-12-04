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
    func testDecodeKeyError() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"foo": "bar"}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
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

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "Value: \(self.value)"
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"value": "bar"}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
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

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{"name": null}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
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

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let body = ByteBufferAllocator().buffer(string: #"{invalid}"#)

            try await client.XCTExecute(
                uri: "/hello",
                method: .post,
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
            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "Hello \(self.name)"
            }
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.post("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .post, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Hello Adam")
            }
        }
    }

    func testDecodeFutureResponse() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String
            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                "Hello \(self.name)"
            }
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.put("/hello", use: DecodeTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/hello", method: .put, body: ByteBufferAllocator().buffer(string: #"{"name": "Adam"}"#)) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Hello Adam")
            }
        }
    }

    func testDecodeFail() async throws {
        struct DecodeTest: HBRequestDecodable {
            let name: String

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> HTTPResponse.Status {
                return .ok
            }
        }
        let router = HBRouter(context: HBTestRouterContext.self)
        router.middlewares.add(HBSetCodableMiddleware(decoder: JSONDecoder(), encoder: JSONEncoder()))
        router.get("/hello", use: DecodeTest.self)
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

            func handle(request: HBRequest, context: some HBBaseRequestContext) -> String {
                return "\(self.parameter)"
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self)
        router.put("/:test", use: ParameterTest.self)
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in

            try await client.XCTExecute(uri: "/23", method: .put) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "23")
            }
        }
    }
}
