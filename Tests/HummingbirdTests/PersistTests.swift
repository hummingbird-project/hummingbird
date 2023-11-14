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
import HummingbirdXCT
import XCTest

final class PersistTests: XCTestCase {
    static let redisHostname = HBEnvironment.shared.get("REDIS_HOSTNAME") ?? "localhost"

    func persistRoutes<Context: HBRequestContext, C: Clock>(_ persist: HBMemoryPersistDriver<C>) -> some HBMiddlewareProtocol<Context> {
        return RouteGroup(context: Context.self) {
            Put("/persist/:tag") { request, context -> HTTPResponseStatus in
                let buffer = try await request.body.collect(upTo: .max)
                guard buffer.readableBytes > 0 else { throw HBHTTPError(.badRequest) }
                let tag = try context.parameters.require("tag")
                try await persist.set(key: tag, value: String(buffer: buffer))
                return .ok
            }
            Put("/persist/:tag/:time") { request, context -> HTTPResponseStatus in
                guard let time = context.parameters.get("time", as: Int.self) else { throw HBHTTPError(.badRequest) }
                let buffer = try await request.body.collect(upTo: .max)
                guard buffer.readableBytes > 0 else { throw HBHTTPError(.badRequest) }
                let tag = try context.parameters.require("tag")
                try await persist.set(key: tag, value: String(buffer: buffer), expires: .seconds(time))
                return .ok
            }
            Get("/persist/:tag") { _, context -> String? in
                guard let tag = context.parameters.get("tag", as: String.self) else { throw HBHTTPError(.badRequest) }
                return try await persist.get(key: tag, as: String.self)
            }
            Delete("/persist/:tag") { _, context -> HTTPResponseStatus in
                guard let tag = context.parameters.get("tag", as: String.self) else { throw HBHTTPError(.badRequest) }
                try await persist.remove(key: tag)
                return .noContent
            }
        }
    }

    func testSetGet() async throws {
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) { self.persistRoutes(persist) }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testCreateGet() async throws {
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
            Put("/create/:tag") { request, context -> HTTPResponseStatus in
                let buffer = try await request.body.collect(upTo: .max)
                guard buffer.readableBytes > 0 else { throw HBHTTPError(.badRequest) }
                let tag = try context.parameters.require("tag")
                try await persist.create(key: tag, value: String(buffer: buffer))
                return .ok
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/create/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testDoubleCreateFail() async throws {
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
            Put("/create/:tag") { request, context -> HTTPResponseStatus in
                let buffer = try await request.body.collect(upTo: .max)
                guard buffer.readableBytes > 0 else { throw HBHTTPError(.badRequest) }
                let tag = try context.parameters.require("tag")
                do {
                    try await persist.create(key: tag, value: String(buffer: buffer))
                } catch let error as HBPersistError where error == .duplicate {
                    throw HBHTTPError(.conflict)
                }
                return .ok
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
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
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in

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
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in

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
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
            Put("/codable/:tag") { request, context -> HTTPResponseStatus in
                guard let tag = context.parameters.get("tag") else { throw HBHTTPError(.badRequest) }
                let buffer = try await request.body.collect(upTo: .max)
                guard buffer.readableBytes > 0 else { throw HBHTTPError(.badRequest) }
                try await persist.set(key: tag, value: TestCodable(buffer: String(buffer: buffer)))
                return .ok
            }
            Get("/codable/:tag") { _, context -> String? in
                guard let tag = context.parameters.get("tag") else { throw HBHTTPError(.badRequest) }
                let value = try await persist.get(key: tag, as: TestCodable.self)
                return value?.buffer
            }
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in

            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/codable/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.XCTExecute(uri: "/codable/\(tag)", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "Persist")
            }
        }
    }

    func testRemove() async throws {
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .PUT, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .DELETE) { _ in }
            try await client.XCTExecute(uri: "/persist/\(tag)", method: .GET) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testExpireAndAdd() async throws {
        let persist = HBMemoryPersistDriver()
        let router = HBRouter(context: HBTestRouterContext.self) {
            self.persistRoutes(persist)
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in

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
