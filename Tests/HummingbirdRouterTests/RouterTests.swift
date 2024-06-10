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

import Hummingbird
import HummingbirdRouter
import HummingbirdTesting
import Logging
import NIOCore
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware<Context: BaseRequestContext>: RouterMiddleware {
        let output: String

        init(_ output: String = "TestMiddleware") {
            self.output = output
        }

        func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
            var response = try await next(request, context)
            response.headers[.middleware] = self.output
            return response
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() async throws {
        struct TestEndpointMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("/test/{number}") { _, _ in
                return "xxx"
            }
        }
        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/1", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/test/{number}")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: BaseRequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("test") { _, context in
                return context.endpointPath
            }
            Get { _, context in
                return context.endpointPath
            }
            Post("/test2") { _, context in
                return context.endpointPath
            }
        }
        let app = Application(responder: router)

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
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("test/") { _, context in
                return context.endpointPath
            }
            Post("test2") { _, context in
                return context.endpointPath
            }
            RouteGroup("testGroup") {
                Get { _, context in
                    return context.endpointPath
                }
            }
            RouteGroup("testGroup2") {
                Get("/") { _, context in
                    return context.endpointPath
                }
            }
        }
        let app = Application(responder: router)
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
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/endpoint") {
                Get { _, _ in
                    return "GET"
                }
                Put { _, _ in
                    return "PUT"
                }
            }
        }
        let app = Application(responder: router)
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
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Get { _, _ in
                    return "hello"
                }
            }
            Get("/not-group") { _, _ in
                return "hello"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }

            try await client.execute(uri: "/not-group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], nil)
            }
        }
    }

    func testEndpointMiddleware() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Head { _, _ in
                    return "hello"
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .head) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/test") {
                TestMiddleware()
                RouteGroup("/group") {
                    Get { _, _ in
                        return "hello"
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() async throws {
        struct TestGroupMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext2
            let output: String

            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string = self.output
                return try await next(request, context)
            }
        }

        let router = RouterBuilder(context: TestRouterContext2.self) {
            RouteGroup("/test") {
                TestGroupMiddleware(output: "route1")
                Get { _, context in
                    return context.string
                }
                RouteGroup("/group") {
                    TestGroupMiddleware(output: "route2")
                    Get { _, context in
                        return context.string
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "route2")
            }
            try await client.execute(uri: "/test", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "route1")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testRouteBuilder() async throws {
        struct TestGroupMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext2
            let output: String

            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string += self.output
                return try await next(request, context)
            }
        }

        @Sendable func handle(_: Request, _ context: TestRouterContext2) async throws -> String {
            context.string
        }
        let router = RouterBuilder(context: TestRouterContext2.self) {
            RouteGroup("/test") {
                Get {
                    TestGroupMiddleware(output: "route1")
                    handle
                }
                Post {
                    TestGroupMiddleware(output: "route2")
                    Handle { _, context in
                        return context.string
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "route1")
            }
            try await client.execute(uri: "/test", method: .post) { response in
                XCTAssertEqual(String(buffer: response.body), "route2")
            }
        }
    }

    /// Test the hummingbird core parser against possible overflows of the percent encoder. this issue was introduced in pr #404 in the context of query parameters but I've thrown in some other random overflow scenarios in here too for good measure. if it doesn't crash, its a win.
    func testQueryParameterOverflow() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("overflow") { req, _ in
                let currentQP = req.uri.queryParameters["query"]
                return String("\(currentQP ?? "")")
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/overflow?query=value%", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "value%")
            }
            try await client.execute(uri: "/overflow?query%=value%", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "")
            }
            try await client.execute(uri: "/overflow?%&", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "")
            }
        }
    }

    func testParameters() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Delete("/user/:id") { _, context -> String? in
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/1234", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "1234")
            }
        }
    }

    func testParameterCollection() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Delete("/user/:username/:id") { _, context -> String? in
                XCTAssertEqual(context.parameters.count, 2)
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/john/1234", method: .delete) { response in
                XCTAssertEqual(String(buffer: response.body), "1234")
            }
        }
    }

    func testPartialCapture() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Route(.get, "/files/file.{ext}/{name}.jpg") { _, context -> String in
                XCTAssertEqual(context.parameters.count, 2)
                let ext = try context.parameters.require("ext")
                let name = try context.parameters.require("name")
                return "\(name).\(ext)"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "test.doc")
            }
        }
    }

    func testPartialWildcard() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("/files/file.*/*.jpg") { _, _ -> HTTPResponse.Status in
                return .ok
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.execute(uri: "/files/file.doc/test.png", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    /// Test we have a request id and that it increments with each request
    func testRequestId() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("id") { _, context in
                return context.id.description
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            let id = try await client.execute(uri: "/id", method: .get) { response -> String in
                return String(buffer: response.body)
            }
            try await client.execute(uri: "/id", method: .get) { response in
                let id2 = String(buffer: response.body)
                XCTAssertNotEqual(id2, id)
            }
        }
    }

    // Test redirect response
    func testRedirect() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("redirect") { _, _ in
                return Response.redirect(to: "/other")
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/redirect", method: .get) { response in
                XCTAssertEqual(response.headers[.location], "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }

    func testResponderBuilder() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("hello") { _, _ in
                return "hello"
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "hello")
            }
        }
    }
}

public struct TestRouterContext2: RouterRequestContext, RequestContext {
    /// router context
    public var routerContext: RouterBuilderContext
    /// core context
    public var coreContext: CoreRequestContext

    /// additional data
    public var string: String

    public init(source: Source) {
        self.routerContext = .init()
        self.coreContext = .init(source: source)
        self.string = ""
    }
}
