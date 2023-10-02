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

@testable import Hummingbird
import HummingbirdXCT
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware: HBMiddleware {
        let output: String

        init(_ output: String = "TestMiddleware") {
            self.output = output
        }

        func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
            return next.respond(to: request, context: context).map { response in
                var response = response
                response.headers.replaceOrAdd(name: "middleware", value: self.output)
                return response
            }
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() async throws {
        struct TestEndpointMiddleware: HBMiddleware {
            func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
                guard let endpointPath = request.endpointPath else { return next.respond(to: request, context: context) }
                return context.success(.init(status: .ok, body: .byteBuffer(ByteBuffer(string: endpointPath))))
            }
        }

        let app = HBApplicationBuilder()
        app.middleware.add(TestEndpointMiddleware())
        app.router.get("/test/:number") { _, _ in return "xxx" }

        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test/1", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test/:number")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware: HBMiddleware {
            func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
                guard let endpointPath = request.endpointPath else { return next.respond(to: request, context: context) }
                return context.success(.init(status: .ok, body: .byteBuffer(ByteBuffer(string: endpointPath))))
            }
        }

        let app = HBApplicationBuilder()
        app.middleware.add(TestEndpointMiddleware())
        app.router.get("test") { req, _ in
            return req.endpointPath
        }
        app.router.get { req, _ in
            return req.endpointPath
        }
        app.router.post("/test2") { req, _ in
            return req.endpointPath
        }

        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/")
            }
            try await client.XCTExecute(uri: "/test/", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test")
            }
            try await client.XCTExecute(uri: "/test2/", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test2")
            }
        }
    }

    /// Test endpointPath doesn't have "/" at end
    func testEndpointPathSuffix() async throws {
        struct TestEndpointMiddleware: HBMiddleware {
            func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
                guard let endpointPath = request.endpointPath else { return next.respond(to: request, context: context) }
                return context.success(.init(status: .ok, body: .byteBuffer(ByteBuffer(string: endpointPath))))
            }
        }

        let app = HBApplicationBuilder()
        app.middleware.add(TestEndpointMiddleware())
        app.router.get("test/") { req, _ in
            return req.endpointPath
        }
        app.router.post("test2") { req, _ in
            return req.endpointPath
        }
        app.router
            .group("testGroup")
            .get { req, _ in
                return req.endpointPath
            }
        app.router
            .group("testGroup2")
            .get("/") { req, _ in
                return req.endpointPath
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test/", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test")
            }

            try await client.XCTExecute(uri: "/test2/", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test2")
            }

            try await client.XCTExecute(uri: "/testGroup/", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/testGroup")
            }

            try await client.XCTExecute(uri: "/testGroup2", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/testGroup2")
            }
        }
    }

    /// Test correct endpoints are called from group
    func testMethodEndpoint() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/endpoint")
            .get { _, _ in
                return "GET"
            }
            .put { _, _ in
                return "PUT"
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/endpoint", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }

            try await client.XCTExecute(uri: "/endpoint", method: .PUT) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "PUT")
            }
        }
    }

    /// Test middle in group is applied to group but not to routes outside
    /// group
    func testGroupMiddleware() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group()
            .add(middleware: TestMiddleware())
            .get("/group") { _, _ in
                return "hello"
            }
        app.router.get("/not-group") { _, _ in
            return "hello"
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }

            try await client.XCTExecute(uri: "/not-group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, nil)
            }
        }
    }

    func testEndpointMiddleware() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/group")
            .add(middleware: TestMiddleware())
            .head { _, _ in
                return "hello"
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/group", method: .HEAD) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() async throws {
        let app = HBApplicationBuilder()
        app.router
            .group("/test")
            .add(middleware: TestMiddleware())
            .group("/group")
            .get { request, context in
                return context.success("hello")
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test/group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() async throws {
        struct TestGroupMiddleware: HBMiddleware {
            let output: String

            func apply(to request: HBRequest, context: HBRequestContext, next: HBResponder) -> EventLoopFuture<HBResponse> {
                var request = request
                request.string = self.output
                return next.respond(to: request, context: context)
            }
        }

        let app = HBApplicationBuilder()
        app.router
            .group("/test")
            .add(middleware: TestGroupMiddleware(output: "route1"))
            .get { request, context in
                return context.success(request.string)
            }
            .group("/group")
            .add(middleware: TestGroupMiddleware(output: "route2"))
            .get { request, context in
                return context.success(request.string)
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test/group", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route2")
            }
            try await client.XCTExecute(uri: "/test", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route1")
            }
        }
    }

    func testParameters() async throws {
        let app = HBApplicationBuilder()
        app.router
            .delete("/user/:id") { request, context -> String? in
                return request.parameters.get("id", as: String.self)
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/user/1234", method: .DELETE) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testParameterCollection() async throws {
        let app = HBApplicationBuilder()
        app.router
            .delete("/user/:username/:id") { request, context -> String? in
                XCTAssertEqual(request.parameters.count, 2)
                return request.parameters.get("id", as: String.self)
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/user/john/1234", method: .DELETE) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testPartialCapture() async throws {
        let app = HBApplicationBuilder()
        app.router
            .get("/files/file.${ext}/${name}.jpg") { request, context -> String in
                XCTAssertEqual(request.parameters.count, 2)
                let ext = try request.parameters.require("ext")
                let name = try request.parameters.require("name")
                return "\(name).\(ext)"
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/files/file.doc/test.jpg", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "test.doc")
            }
        }
    }

    func testPartialWildcard() async throws {
        let app = HBApplicationBuilder()
        app.router
            .get("/files/file.*/*.jpg") { _, _ -> HTTPResponseStatus in
                return .ok
            }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/files/file.doc/test.jpg", method: .GET) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.XCTExecute(uri: "/files/file.doc/test.png", method: .GET) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    /// Test we have a request id and that it increments with each request
    func testRequestId() async throws {
        let app = HBApplicationBuilder()
        app.router.get("id") { req, _ in 
            return req.id
        }
        try await app.buildAndTest(.router) { client in
            let idString = try await client.XCTExecute(uri: "/id", method: .GET) { response -> String in
                let body = try XCTUnwrap(response.body)
                return String(buffer: body)
            }
            let id = try XCTUnwrap(Int(idString))
            try await client.XCTExecute(uri: "/id", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                let id2 = Int(String(buffer: body))
                XCTAssertEqual(id2, id + 1)
            }
        }
    }

    // Test redirect response
    func testRedirect() async throws {
        let app = HBApplicationBuilder()
        app.router.get("redirect") { _, _ in
            return HBResponse.redirect(to: "/other")
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/redirect", method: .GET) { response in
                XCTAssertEqual(response.headers["location"].first, "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }
}

extension HBRequest {
    var string: String {
        get { self.extensions.get(\.string) }
        set { self.extensions.set(\.string, value: newValue) }
    }
}
