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
import XCTest

final class AsyncPersistTests: XCTestCase {
    func createApplication() throws -> (HBApplicationBuilder, HBPersistDriver) {
        let app = HBApplicationBuilder()
        let persist: HBPersistDriver = HBMemoryPersistDriver(eventLoopGroup: app.eventLoopGroup)

        app.router.put("/persist/:tag") { request, context -> HTTPResponseStatus in
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            let tag = try context.parameters.require("tag")
            try await persist.set(key: tag, value: String(buffer: buffer), request: request)
            return .ok
        }
        app.router.put("/persist/:tag/:time") { request, context -> HTTPResponseStatus in
            guard let time = context.parameters.get("time", as: Int.self) else { throw HBHTTPError(.badRequest) }
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            let tag = try context.parameters.require("tag")
            try await persist.set(key: tag, value: String(buffer: buffer), expires: .seconds(numericCast(time)), request: request)
            return .ok
        }
        app.router.get("/persist/:tag") { request, context -> String? in
            let tag = try context.parameters.require("tag")
            return try await persist.get(key: tag, as: String.self, request: request)
        }
        app.router.delete("/persist/:tag") { request, context -> HTTPResponseStatus in
            let tag = try context.parameters.require("tag")
            try await persist.remove(key: tag, request: request)
            return .noContent
        }
        return (app, persist)
    }

    func testSetGet() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, _) = try createApplication()
        try await app.buildAndTest(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testCreateGet() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, persist) = try createApplication()
        app.router.put("/create/:tag") { request, context -> HTTPResponseStatus in
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            let tag = try context.parameters.require("tag")
            try await persist.create(key: tag, value: String(buffer: buffer), request: request)
            return .ok
        }
        try await app.buildAndTest(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testDoubleCreateFail() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, persist) = try createApplication()
        app.router.put("/create/:tag") { request, context -> HTTPResponseStatus in
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            let tag = try context.parameters.require("tag")
            do {
                try await persist.create(key: tag, value: String(buffer: buffer), request: request)
            } catch let error as HBPersistError where error == .duplicate {
                throw HBHTTPError(.conflict)
            }
            return .ok
        }
        try await app.buildAndTest(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
                XCTAssertEqual(response.status, .conflict)
            }
        }
    }

    func testSetTwice() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, _) = try createApplication()
        try await app.buildAndTest(.router) { client in

            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "test1")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "test2")) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "test2")
            }
        }
    }

    func testExpires() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, _) = try createApplication()
        try await app.buildAndTest(.router) { client in

            let tag1 = UUID().uuidString
            let tag2 = UUID().uuidString

            try await client.XCTExecute(uri: "/persist/\(tag1)/0", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag2)/10", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest2")) { _ in }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.XCTExecute(uri: "/persist/\(tag1)", method: .GET) { response in
                XCTAssertEqual(response.status, .noContent)
            }
            try await client.XCTExecute(uri: "/persist/\(tag2)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "ThisIsTest2")
            }
        }
    }

    func testCodable() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        struct TestCodable: Codable {
            let buffer: String
        }
        let (app, persist) = try createApplication()

        app.router.put("/codable/:tag") { request, context -> HTTPResponseStatus in
            guard let tag = context.parameters.get("tag") else { throw HBHTTPError(.badRequest) }
            guard let buffer = request.body.buffer else { throw HBHTTPError(.badRequest) }
            try await persist.set(key: tag, value: TestCodable(buffer: String(buffer: buffer)), request: request)
            return .ok
        }
        app.router.get("/codable/:tag") { request, context -> String? in
            guard let tag = context.parameters.get("tag") else { throw HBHTTPError(.badRequest) }
            let value = try await persist.get(key: tag, as: TestCodable.self, request: request)
            return value?.buffer
        }
        try await app.buildAndTest(.router) { client in

            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/codable/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/codable/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testRemove() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, _) = try createApplication()
        try await app.buildAndTest(.router) { client in

            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .DELETE) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testExpireAndAdd() async throws {
        #if os(macOS)
        // disable macOS tests in CI. GH Actions are currently running this when they shouldn't
        guard HBEnvironment().get("CI") != "true" else { throw XCTSkip() }
        #endif
        let (app, _) = try createApplication()
        try await app.buildAndTest(.router) { client in

            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)/0", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                XCTAssertEqual(response.status, .noContent)
            }
            try await client.XCTExecute(uri: "/persist/\(tag)/10", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "ThisIsTest1")
            }
        }
    }
}
