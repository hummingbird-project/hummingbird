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
    static let redisHostname = HBEnvironment.shared.get("REDIS_HOSTNAME") ?? "localhost"

    func createApplication() throws -> HBApplication {
        let app = HBApplication(testing: .embedded)
        // add persist
        app.addPersist(using: .memory)

        app.router.put("/persist/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return request.persist.set(key: tag, value: String(buffer: buffer))
                .map { _ in .ok }
        }
        app.router.put("/persist/:tag/:time") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let time = request.parameters.get("time", as: Int.self) else { return request.failure(.badRequest) }
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return request.persist.set(key: tag, value: String(buffer: buffer), expires: .seconds(numericCast(time)))
                .map { _ in .ok }
        }
        app.router.get("/persist/:tag") { request -> EventLoopFuture<String?> in
            guard let tag = request.parameters.get("tag", as: String.self) else { return request.failure(.badRequest) }
            return request.persist.get(key: tag, as: String.self)
        }
        app.router.delete("/persist/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag", as: String.self) else { return request.failure(.badRequest) }
            return request.persist.remove(key: tag)
                .map { _ in .noContent }
        }
        return app
    }

    func testSetGet() throws {
        let app = try createApplication()
        try app.XCTStart()
        defer { app.XCTStop() }
        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist")
        }
    }

    func testCreateGet() throws {
        let app = try createApplication()
        app.router.put("/create/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return request.persist.create(key: tag, value: String(buffer: buffer))
                .map { _ in .ok }
        }
        try app.XCTStart()
        defer { app.XCTStop() }
        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist")
        }
    }

    func testDoubleCreateFail() throws {
        let app = try createApplication()
        app.router.put("/create/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return request.persist.create(key: tag, value: String(buffer: buffer))
                .flatMapErrorThrowing { error in
                    if let error = error as? HBPersistError, error == .duplicate { throw HBHTTPError(.conflict) }
                    throw error
                }
                .map { _ in .ok }
        }
        try app.XCTStart()
        defer { app.XCTStop() }
        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
            XCTAssertEqual(response.status, .ok)
        }
        try app.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
            XCTAssertEqual(response.status, .conflict)
        }
    }

    func testSetTwice() throws {
        let app = try createApplication()
        try app.XCTStart()
        defer { app.XCTStop() }

        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "test1")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "test2")) { response in
            XCTAssertEqual(response.status, .ok)
        }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "test2")
        }
    }

    func testExpires() throws {
        let app = try createApplication()
        try app.XCTStart()
        defer { app.XCTStop() }

        let tag1 = UUID().uuidString
        let tag2 = UUID().uuidString

        try app.XCTExecute(uri: "/persist/\(tag1)/0", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag2)/10", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest2")) { _ in }
        Thread.sleep(forTimeInterval: 1)
        try app.XCTExecute(uri: "/persist/\(tag1)", method: .GET) { response in
            XCTAssertEqual(response.status, .noContent)
        }
        try app.XCTExecute(uri: "/persist/\(tag2)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "ThisIsTest2")
        }
    }

    func testCodable() throws {
        struct TestCodable: Codable {
            let buffer: String
        }
        let app = try createApplication()

        app.router.put("/codable/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return request.persist.set(key: tag, value: TestCodable(buffer: String(buffer: buffer)))
                .map { _ in .ok }
        }
        app.router.get("/codable/:tag") { request -> EventLoopFuture<String?> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            return request.persist.get(key: tag, as: TestCodable.self).map { $0.map(\.buffer) }
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/codable/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        try app.XCTExecute(uri: "/codable/\(tag)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist")
        }
    }

    func testRemove() throws {
        let app = try createApplication()
        try app.XCTStart()
        defer { app.XCTStop() }

        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .DELETE) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            XCTAssertEqual(response.status, .noContent)
        }
    }

    func testExpireAndAdd() throws {
        let app = try createApplication()
        try app.XCTStart()
        defer { app.XCTStop() }

        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/persist/\(tag)/0", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
        Thread.sleep(forTimeInterval: 1)
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            XCTAssertEqual(response.status, .noContent)
        }
        try app.XCTExecute(uri: "/persist/\(tag)/10", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { response in
            XCTAssertEqual(response.status, .ok)
        }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            XCTAssertEqual(response.status, .ok)
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "ThisIsTest1")
        }
    }

    func testSetGetOutsideApp() throws {
        let app = HBApplication(testing: .embedded)
        let persist = HBMemoryPersistDriver(eventLoopGroup: app.eventLoopGroup)

        app.router.put("/persist/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return persist.create(key: tag, value: String(buffer: buffer), request: request)
                .map { _ in .ok }
        }
        app.router.patch("/persist/:tag") { request -> EventLoopFuture<HTTPResponseStatus> in
            guard let tag = request.parameters.get("tag") else { return request.failure(.badRequest) }
            guard let buffer = request.body.buffer else { return request.failure(.badRequest) }
            return persist.set(key: tag, value: String(buffer: buffer), request: request)
                .map { _ in .ok }
        }
        app.router.get("/persist/:tag") { request -> EventLoopFuture<String?> in
            guard let tag = request.parameters.get("tag", as: String.self) else { return request.failure(.badRequest) }
            return persist.get(key: tag, as: String.self, request: request)
        }
        try app.XCTStart()
        defer { app.XCTStop() }
        let tag = UUID().uuidString
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .PATCH, body: ByteBufferAllocator().buffer(string: "Persist2")) { _ in }
        try app.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "Persist2")
        }
    }
}
