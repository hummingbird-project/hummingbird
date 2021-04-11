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

@testable import Hummingbird
import XCTest

final class PersistTests: XCTestCase {
    func testSetGet() {
        let app = HBApplication(testing: .live)
        app.addPersist(using: .memory)
        app.router.put("/") { request -> HTTPResponseStatus in
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            request.persist.set(key: "test", value: String(buffer: buffer))
            return .ok
        }
        app.router.get("/") { request in
            return request.persist.get(key: "test", as: String.self)
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        app.XCTExecute(uri: "/", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist")
        }
    }

    func testExpires() {
        let app = HBApplication(testing: .live)
        app.addPersist(using: .memory)
        app.router.put("/persist/:tag/:time") { request -> HTTPResponseStatus in
            let time = try request.parameters.require("time", as: Int.self)
            let tag = try request.parameters.require("tag")
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            request.persist.set(key: tag, value: String(buffer: buffer), expires: .seconds(numericCast(time)))
            return .ok
        }
        app.router.get("/persist/:tag") { request -> EventLoopFuture<String?> in
            guard let tag = request.parameters.get("tag", as: String.self) else { return request.failure(.badRequest) }
            return request.persist.get(key: tag, as: String.self)
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/persist/test1/-5", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
        app.XCTExecute(uri: "/persist/test2/5", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest2")) { _ in }
        app.XCTExecute(uri: "/persist/test1", method: .GET) { response in
            XCTAssertEqual(response.status, .notFound)
        }
        app.XCTExecute(uri: "/persist/test2", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "ThisIsTest2")
        }
    }

    func testCodable() {
        struct TestCodable: Codable {
            let buffer: String
        }
        let app = HBApplication(testing: .live)
        app.addPersist(using: .memory)
        app.router.put("/") { request -> HTTPResponseStatus in
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            request.persist.set(key: "test", value: TestCodable(buffer: String(buffer: buffer)))
            return .ok
        }
        app.router.get("/") { request in
            return request.persist.get(key: "test", as: TestCodable.self).map { $0.map(\.buffer) }
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        app.XCTExecute(uri: "/", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist")
        }
    }

    func testRemove() {
        let app = HBApplication(testing: .live)
        app.addPersist(using: .memory)
        app.router.put("/persist/:tag") { request -> HTTPResponseStatus in
            let tag = try request.parameters.require("tag")
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            request.persist.set(key: tag, value: String(buffer: buffer))
            return .ok
        }
        app.router.get("/persist/:tag") { request -> EventLoopFuture<String?> in
            guard let tag = request.parameters.get("tag", as: String.self) else { return request.failure(.badRequest) }
            return request.persist.get(key: tag, as: String.self)
        }
        app.router.delete("/persist/:tag") { request -> HTTPResponseStatus in
            guard let tag = request.parameters.get("tag", as: String.self) else { throw HBHTTPError(.badRequest) }
            request.persist.remove(key: tag)
            return .noContent
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/persist/test1", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
        app.XCTExecute(uri: "/persist/test1", method: .DELETE) { _ in }
        app.XCTExecute(uri: "/persist/test1", method: .GET) { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }
}
