//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

struct PersistTests {
    static let redisHostname = Environment().get("REDIS_HOSTNAME") ?? "localhost"

    func createRouter(
        configuration: MemoryPersistDriver<ContinuousClock>.Configuration = .init()
    ) throws -> (Router<BasicRequestContext>, PersistDriver) {
        let router = Router()
        let persist = MemoryPersistDriver(configuration: configuration)

        router.put("/persist/:tag") { request, context -> HTTPResponse.Status in
            let buffer = try await request.body.collect(upTo: .max)
            let tag = try context.parameters.require("tag")
            try await persist.set(key: tag, value: String(buffer: buffer))
            return .ok
        }
        router.put("/persist/:tag/:time") { request, context -> HTTPResponse.Status in
            guard let time = context.parameters.get("time", as: Int.self) else { throw HTTPError(.badRequest) }
            let buffer = try await request.body.collect(upTo: .max)
            let tag = try context.parameters.require("tag")
            try await persist.set(key: tag, value: String(buffer: buffer), expires: .seconds(time))
            return .ok
        }
        router.get("/persist/:tag") { _, context -> String? in
            guard let tag = context.parameters.get("tag", as: String.self) else { throw HTTPError(.badRequest) }
            return try await persist.get(key: tag, as: String.self)
        }
        router.delete("/persist/:tag") { _, context -> HTTPResponse.Status in
            guard let tag = context.parameters.get("tag", as: String.self) else { throw HTTPError(.badRequest) }
            try await persist.remove(key: tag)
            return .noContent
        }
        return (router, persist)
    }

    @Test func testSetGet() async throws {
        let (router, _) = try createRouter()
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.execute(uri: "/persist/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(String(buffer: response.body) == "Persist")
            }
        }
    }

    @Test func testCreateGet() async throws {
        let (router, persist) = try createRouter()

        router.put("/create/:tag") { request, context -> HTTPResponse.Status in
            let buffer = try await request.body.collect(upTo: .max)
            let tag = try context.parameters.require("tag")
            try await persist.create(key: tag, value: String(buffer: buffer))
            return .ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.execute(uri: "/create/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(String(buffer: response.body) == "Persist")
            }
        }
    }

    @Test func testDoubleCreateFail() async throws {
        let (router, persist) = try createRouter()
        router.put("/create/:tag") { request, context -> HTTPResponse.Status in
            let buffer = try await request.body.collect(upTo: .max)
            let tag = try context.parameters.require("tag")
            do {
                try await persist.create(key: tag, value: String(buffer: buffer))
            } catch let error as PersistError where error == .duplicate {
                throw HTTPError(.conflict)
            }
            return .ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.execute(uri: "/create/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/create/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "Persist")) { response in
                #expect(response.status == .conflict)
            }
        }
    }

    @Test func testSetTwice() async throws {
        let (router, _) = try createRouter()
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let tag = UUID().uuidString
            try await client.execute(uri: "/persist/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "test1")) { _ in }
            try await client.execute(uri: "/persist/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "test2")) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(String(buffer: response.body) == "test2")
            }
        }
    }

    @Test func testExpires() async throws {
        let (router, _) = try createRouter()
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let tag1 = UUID().uuidString
            let tag2 = UUID().uuidString

            try await client.execute(uri: "/persist/\(tag1)/0", method: .put, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await client.execute(uri: "/persist/\(tag2)/10", method: .put, body: ByteBufferAllocator().buffer(string: "ThisIsTest2")) { _ in }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.execute(uri: "/persist/\(tag1)", method: .get) { response in
                #expect(response.status == .noContent)
            }
            try await client.execute(uri: "/persist/\(tag2)", method: .get) { response in
                #expect(String(buffer: response.body) == "ThisIsTest2")
            }
        }
    }

    @Test func testCodable() async throws {
        struct TestCodable: Codable {
            let buffer: String
        }
        let (router, persist) = try createRouter()
        router.put("/codable/:tag") { request, context -> HTTPResponse.Status in
            guard let tag = context.parameters.get("tag") else { throw HTTPError(.badRequest) }
            let buffer = try await request.body.collect(upTo: .max)
            try await persist.set(key: tag, value: TestCodable(buffer: String(buffer: buffer)))
            return .ok
        }
        router.get("/codable/:tag") { _, context -> String? in
            guard let tag = context.parameters.get("tag") else { throw HTTPError(.badRequest) }
            let value = try await persist.get(key: tag, as: TestCodable.self)
            return value?.buffer
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in

            let tag = UUID().uuidString
            try await client.execute(uri: "/codable/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "Persist")) { _ in }
            try await client.execute(uri: "/codable/\(tag)", method: .get) { response in
                #expect(String(buffer: response.body) == "Persist")
            }
        }
    }

    @Test func testInvalidGetAs() async throws {
        struct TestCodable: Codable {
            let buffer: String
        }
        let (router, persist) = try createRouter()
        router.put("/invalid") { _, _ -> HTTPResponse.Status in
            try await persist.set(key: "test", value: TestCodable(buffer: "hello"))
            return .ok
        }
        router.get("/invalid") { _, _ -> String? in
            do {
                return try await persist.get(key: "test", as: String.self)
            } catch let error as PersistError where error == .invalidConversion {
                throw HTTPError(.badRequest)
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/invalid", method: .put)
            try await client.execute(uri: "/invalid", method: .get) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test func testRemove() async throws {
        let (router, _) = try createRouter()
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.execute(uri: "/persist/\(tag)", method: .put, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await client.execute(uri: "/persist/\(tag)", method: .delete) { _ in }
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(response.status == .noContent)
            }
        }
    }

    @Test func testExpireAndAdd() async throws {
        let (router, _) = try createRouter()
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in

            let tag = UUID().uuidString
            try await client.execute(uri: "/persist/\(tag)/0", method: .put, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { _ in }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(response.status == .noContent)
            }
            try await client.execute(uri: "/persist/\(tag)/10", method: .put, body: ByteBufferAllocator().buffer(string: "ThisIsTest1")) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "ThisIsTest1")
            }
        }
    }

    @Test func testTidy() async throws {
        let (router, persist) = try createRouter(configuration: .init(tidyFrequency: .milliseconds(1)))
        let app = Application(responder: router.buildResponder(), services: [persist])
        try await app.test(.router) { client in
            let tag = UUID().uuidString
            try await client.execute(uri: "/persist/\(tag)/10", method: .put, body: ByteBufferAllocator().buffer(string: "NotExpired")) { _ in }
            try await Task.sleep(for: .milliseconds(20))
            try await client.execute(uri: "/persist/\(tag)", method: .get) { response in
                #expect(String(buffer: response.body) == "NotExpired")
            }
        }
    }
}
