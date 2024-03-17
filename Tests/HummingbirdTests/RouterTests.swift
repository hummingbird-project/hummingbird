//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
@testable import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Tracing
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
        let output: String

        init(_ output: String = "TestMiddleware") {
            self.output = output
        }

        public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
            var response = try await next(request, context)
            response.headers[.test] = self.output
            return response
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() async throws {
        struct TestEndpointMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("/test/:number") { _, _ in return "xxx" }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/1", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/test/:number")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("test") { _, context in
            return context.endpointPath
        }
        router.get { _, context in
            return context.endpointPath
        }
        router.post("/test2") { _, context in
            return context.endpointPath
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/")
            }
            try await client.execute(uri: "/test/", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/test")
            }
            try await client.execute(uri: "/test2/", method: .post) { response in
                XCTAssertEqual(String(buffer: response.body), "/test2")
            }
        }
    }

    /// Test endpointPath doesn't have "/" at end
    func testEndpointPathSuffix() async throws {
        struct TestEndpointMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("test/") { _, context in
            return context.endpointPath
        }
        router.post("test2") { _, context in
            return context.endpointPath
        }
        router
            .group("testGroup")
            .get { _, context in
                return context.endpointPath
            }
        router
            .group("testGroup2")
            .get("/") { _, context in
                return context.endpointPath
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/test")
            }

            try await client.execute(uri: "/test2/", method: .post) { response in
                XCTAssertEqual(String(buffer: response.body), "/test2")
            }

            try await client.execute(uri: "/testGroup/", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/testGroup")
            }

            try await client.execute(uri: "/testGroup2", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/testGroup2")
            }
        }
    }

    /// Test correct endpoints are called from group
    func testMethodEndpoint() async throws {
        let router = Router()
        router
            .group("/endpoint")
            .get { _, _ in
                return "GET"
            }
            .put { _, _ in
                return "PUT"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/endpoint", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "GET")
            }

            try await client.execute(uri: "/endpoint", method: .put) { response in
                XCTAssertEqual(String(buffer: response.body), "PUT")
            }
        }
    }

    /// Test middle in group is applied to group but not to routes outside
    /// group
    func testGroupMiddleware() async throws {
        let router = Router()
        router
            .group()
            .add(middleware: TestMiddleware())
            .get("/group") { _, _ in
                return "hello"
            }
        router.get("/not-group") { _, _ in
            return "hello"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .get) { response in
                XCTAssertEqual(response.headers[.test], "TestMiddleware")
            }

            try await client.execute(uri: "/not-group", method: .get) { response in
                XCTAssertEqual(response.headers[.test], nil)
            }
        }
    }

    func testEndpointMiddleware() async throws {
        let router = Router()
        router
            .group("/group")
            .add(middleware: TestMiddleware())
            .head { _, _ in
                return "hello"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .head) { response in
                XCTAssertEqual(response.headers[.test], "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() async throws {
        let router = Router()
        router
            .group("/test")
            .add(middleware: TestMiddleware())
            .group("/group")
            .get { _, _ in
                return "hello"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(response.headers[.test], "TestMiddleware")
            }
        }
    }

    // TODO: No recursive wildcard test yet

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() async throws {
        struct TestGroupMiddleware: RouterMiddleware {
            let output: String

            public func handle(_ request: Request, context: TestRouterContext2, next: (Request, TestRouterContext2) async throws -> Response) async throws -> Response {
                var context = context
                context.string = self.output
                return try await next(request, context)
            }
        }

        let router = Router(context: TestRouterContext2.self)
        router
            .group("/test")
            .add(middleware: TestGroupMiddleware(output: "route1"))
            .get { _, context in
                return context.string
            }
            .group("/group")
            .add(middleware: TestGroupMiddleware(output: "route2"))
            .get { _, context in
                return context.string
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "route2")
            }
            try await client.execute(uri: "/test", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "route1")
            }
        }
    }

    func testParameters() async throws {
        let router = Router()
        router
            .delete("/user/:id") { _, context -> String? in
                return context.parameters.get("id", as: String.self)
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/1234", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "1234")
            }
        }
    }

    func testRequireLosslessStringParameter() async throws {
        let router = Router()
        router
            .delete("/user/:id") { _, context -> String in
                let id = try context.parameters.require("id", as: Int.self)
                return (id + 1).description
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/1234", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "1235")
            }
            try await client.execute(uri: "/user/what", method: .delete) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testRequireRawRepresentableParameter() async throws {
        enum TestEnum: String {
            case this
            case that
        }
        let router = Router()
        router
            .delete("/user/:id") { _, context -> String in
                return try context.parameters.require("id", as: TestEnum.self).rawValue
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/this", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "this")
            }
            try await client.execute(uri: "/user/what", method: .delete) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testParameterCollection() async throws {
        let router = Router()
        router
            .delete("/user/:username/:id") { _, context -> String? in
                XCTAssertEqual(context.parameters.count, 2)
                return context.parameters.get("id", as: String.self)
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/john/1234", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "1234")
            }
        }
    }

    func testPartialCapture() async throws {
        let router = Router()
        router
            .get("/files/file.{ext}/{name}.jpg") { _, context -> String in
                XCTAssertEqual(context.parameters.count, 2)
                let ext = try context.parameters.require("ext")
                let name = try context.parameters.require("name")
                return "\(name).\(ext)"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "test.doc")
            }
        }
    }

    func testPartialWildcard() async throws {
        let router = Router()
        router
            .get("/files/file.*/*.jpg") { _, _ -> HTTPResponse.Status in
                return .ok
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.execute(uri: "/files/file.doc/test.png", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testRequireLosslessStringQuery() async throws {
        let router = Router()
        router
            .get("/user/") { request, _ -> [Int] in
                let ids = try request.uri.queryParameters.requireAll("id", as: Int.self)
                return ids.map { $0 + 1 }
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/?id=24&id=56", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "[25,57]")
            }
            try await client.execute(uri: "/user/?id=24&id=hello", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testRequireRawRepresentableQuery() async throws {
        enum TestEnum: String, Codable {
            case this
            case and
            case that
        }
        let router = Router()
        router
            .patch("/user/") { request, _ -> [TestEnum] in
                let ids = try request.uri.queryParameters.requireAll("id", as: TestEnum.self)
                return ids
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/?id=this&id=and&id=that", method: .patch) { response in
                XCTAssertEqual(String(buffer: response.body), "[\"this\",\"and\",\"that\"]")
            }
            try await client.execute(uri: "/user/?id=this&id=hello", method: .patch) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    /// Test we have a request id and that it increments with each request
    func testRequestId() async throws {
        let router = Router()
        router.get("id") { _, context in
            return context.id.description
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let id = try await client.execute(uri: "/id", method: .get) { response -> String in
                return String(buffer: response.body)
            }
            try await client.execute(uri: "/id", method: .get) { response in
                let id2 = String(buffer: response.body)
                XCTAssertNotEqual(id, id2)
            }
        }
    }

    // Test redirect response
    func testRedirect() async throws {
        let router = Router()
        router.get("redirect") { _, _ in
            return Response.redirect(to: "/other")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/redirect", method: .get) { response in
                XCTAssertEqual(response.headers[.location], "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }

    // Test case insensitive router works
    func testCaseInsensitive() async throws {
        let router = Router(options: .caseInsensitive)
        router.get("Uppercased") { _, _ in
            return HTTPResponse.Status.ok
        }
        router.get("lowercased") { _, _ in
            return HTTPResponse.Status.ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/uppercased", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.execute(uri: "/LOWERCASED", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    // Test auto generation of HEAD endpoints works
    func testAutoGenerateHeadEndpoints() async throws {
        let router = Router(options: .autoGenerateHeadEndpoints)
        router.get("nohead") { _, _ in
            return "TestString"
        }
        router.head("withhead") { _, _ in
            return Response(status: .ok, headers: [.contentLength: "0", .contentLanguage: "en"], body: .init())
        }
        router.get("withhead") { _, _ in
            return Response(status: .ok, headers: [.contentLength: "999"], body: .init())
        }
        router.post("post") { _, _ in
            return Response(status: .ok, headers: [.contentLength: "999"], body: .init())
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/nohead", method: .head) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.contentLength], "10")
            }
            try await client.execute(uri: "/withhead", method: .head) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.contentLanguage], "en")
            }
            try await client.execute(uri: "/post", method: .head) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }
}

struct TestRouterContext2: RequestContext {
    init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.string = ""
    }

    /// parameters
    var coreContext: CoreRequestContext

    /// additional data
    var string: String
}
