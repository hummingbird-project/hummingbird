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
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Tracing
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
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
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("/test/{number}") { _, _ in "xxx" }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/1", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "/test/{number}")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("test") { _, context in
            context.endpointPath
        }
        router.get { _, context in
            context.endpointPath
        }
        router.post("/test2") { _, context in
            context.endpointPath
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

    func testConstantCapturesParameterRoute() async throws {
        let router = Router()

        router.get("/foo/bar") { _, _ in "foo-bar" }
        router.get("/foo/{id}/baz") { _, _ in "foo-bar-baz" }

        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(
                uri: "/foo/bar/baz",
                method: .get
            ) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "foo-bar-baz")
            }
        }
    }

    /// Test endpointPath doesn't have "/" at end
    func testEndpointPathSuffix() async throws {
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = Router()
        router.middlewares.add(TestEndpointMiddleware())
        router.get("test/") { _, context in
            context.endpointPath
        }
        router.post("test2") { _, context in
            context.endpointPath
        }
        router
            .group("testGroup")
            .get { _, context in
                context.endpointPath
            }
        router
            .group("testGroup2")
            .get("/") { _, context in
                context.endpointPath
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
                "GET"
            }
            .put { _, _ in
                "PUT"
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
                "hello"
            }
        router.get("/not-group") { _, _ in
            "hello"
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
                "hello"
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
                "hello"
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(response.headers[.test], "TestMiddleware")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() async throws {
        struct TestGroupMiddleware: RouterMiddleware {
            let output: String

            public func handle(
                _ request: Request,
                context: TestRouterContext2,
                next: (Request, TestRouterContext2) async throws -> Response
            ) async throws -> Response {
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
                context.string
            }
            .group("/group")
            .add(middleware: TestGroupMiddleware(output: "route2"))
            .get { _, context in
                context.string
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

    /// Test middleware in parent group is applied to routes in child group
    func testTransformingGroupMiddleware() async throws {
        struct TestRouterContext2: RequestContext {
            typealias Source = BasicRequestContext
            init(source: Source) {
                self.coreContext = .init(source: source)
                self.string = ""
            }

            /// parameters
            var coreContext: CoreRequestContextStorage

            /// additional data
            var string: String
        }
        struct TestTransformMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext2
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string = request.headers[.test] ?? ""
                return try await next(request, context)
            }
        }
        let router = Router()
        router
            .group("/test")
            .group("/group", context: TestRouterContext2.self)
            .add(middleware: TestTransformMiddleware())
            .get { _, context in
                EditedResponse(headers: [.test: context.string], response: "hello")
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get, headers: [.test: "test"]) { response in
                XCTAssertEqual(response.headers[.test], "test")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testThrowingTransformingGroupMiddleware() async throws {
        struct TestRouterContext: RequestContext {
            init(source: Source) {
                self.coreContext = .init(source: source)
                self.string = nil
            }

            /// parameters
            var coreContext: CoreRequestContextStorage
            /// additional data
            var string: String?
        }
        struct TestRouterContext2: ChildRequestContext {
            typealias ParentContext = TestRouterContext
            init(context: ParentContext) throws {
                self.coreContext = .init(source: context)
                guard let string = context.string else { throw HTTPError(.badRequest) }
                self.string = string
            }

            /// parameters
            var coreContext: CoreRequestContextStorage
            /// additional data
            var string: String
        }
        struct TestTransformMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string = request.headers[.test]
                return try await next(request, context)
            }
        }
        let router = Router(context: TestRouterContext.self)
        router
            .add(middleware: TestTransformMiddleware())
            .group("/group", context: TestRouterContext2.self)
            .get { _, context in
                EditedResponse(headers: [.test: context.string], response: "hello")
            }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .get, headers: [.test: "test"]) { response in
                XCTAssertEqual(response.headers[.test], "test")
            }
            try await client.execute(uri: "/group", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testParameters() async throws {
        let router = Router()
        router
            .delete("/user/:id") { _, context -> String? in
                context.parameters.get("id", as: String.self)
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
                try context.parameters.require("id", as: TestEnum.self).rawValue
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
                .ok
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
            context.id.description
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let id = try await client.execute(uri: "/id", method: .get) { response in
                String(buffer: response.body)
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
            Response.redirect(to: "/other")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/redirect", method: .get) { response in
                XCTAssertEqual(response.headers[.location], "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }

    // Test route collection added to Router
    func testRouteCollection() async throws {
        let router = Router()
        let routes = RouteCollection()
        routes.get("that") { _, _ in
            HTTPResponse.Status.ok
        }
        router.addRoutes(routes, atPath: "/this")
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/this/that", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    // Test route collection added to Router
    func testRouteCollectionInGroup() async throws {
        let router = Router()
        let routes = RouteCollection()
            .get("that") { _, _ in
                HTTPResponse.Status.ok
            }
        router.group("this").addRoutes(routes)
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/this/that", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    // Test middleware in route collection
    func testMiddlewareInRouteCollection() async throws {
        let router = Router()
        let routes = RouteCollection()
            .add(middleware: TestMiddleware("Hello"))
            .get("that") { _, _ in
                HTTPResponse.Status.ok
            }
        router.addRoutes(routes, atPath: "/this")
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/this/that", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.test], "Hello")
            }
        }
    }

    // Test middleware in route collection is only applied to routes after middleware
    func testMiddlewareOrderingInRouteCollection() async throws {
        let router = Router()
        let routes = RouteCollection()
            .get("this") { _, _ in
                HTTPResponse.Status.ok
            }
            .add(middleware: TestMiddleware("Hello"))
            .get("that") { _, _ in
                HTTPResponse.Status.ok
            }
        router.addRoutes(routes, atPath: "/test")
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/this", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertNil(response.headers[.test])
            }
            try await client.execute(uri: "/test/that", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.test], "Hello")
            }
        }
    }

    // Test group in route collection
    func testGroupInRouteCollection() async throws {
        let router = Router()
        let routes = RouteCollection()
        routes.group("2")
            .add(middleware: TestMiddleware("Hello"))
            .get("3") { _, _ in
                HTTPResponse.Status.ok
            }
        router.addRoutes(routes, atPath: "1")
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/1/2/3", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.test], "Hello")
            }
        }
    }

    // Test case insensitive router works
    func testCaseInsensitive() async throws {
        let router = Router(options: .caseInsensitive)
        router.get("Uppercased") { _, _ in
            HTTPResponse.Status.ok
        }
        router.get("lowercased") { _, _ in
            HTTPResponse.Status.ok
        }
        router.group("group").get("Uppercased") { _, _ in
            HTTPResponse.Status.ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/uppercased", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.execute(uri: "/LOWERCASED", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.execute(uri: "/Group/uppercased", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testRecursiveWildcard() async throws {
        let router = Router()
        router.get("/api/v1/**/john") { _, context in
            "John \(context.parameters.getCatchAll().joined(separator: "/"))"
        }
        router.get("/api/v1/**/jane/subpath") { _, context in
            "Jane \(context.parameters.getCatchAll().joined(separator: "/"))"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/api/v1/a/b/c/d/e/f/john", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "John a/b/c/d/e/f")
            }
            try await client.execute(uri: "/api/v1/a/b/d/e/f/jane/subpath", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "Jane a/b/d/e/f")
            }
        }
    }

    // Test auto generation of HEAD endpoints works
    func testAutoGenerateHeadEndpoints() async throws {
        let router = Router(options: .autoGenerateHeadEndpoints)
        router.get("nohead") { _, _ in
            "TestString"
        }
        router.head("withhead") { _, _ in
            Response(status: .ok, headers: [.contentLength: "0", .contentLanguage: "en"], body: .init())
        }
        router.get("withhead") { _, _ in
            Response(status: .ok, headers: [.contentLength: "999"], body: .init())
        }
        router.post("post") { _, _ in
            Response(status: .ok, headers: [.contentLength: "999"], body: .init())
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

    func testRouterPathStringInterpolation() async throws {
        let route = "/test"
        let router = Router()
        router.get("\(route)") { _, _ in
            "TestString"
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/test", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.contentLength], "10")
            }
        }
    }

    func testEndpointDescriptions() {
        let router = Router()
        router.get("test") { _, _ in "" }
        router.get("test/this") { _, _ in "" }
        router.put("test") { _, _ in "" }
        router.post("{test}/{what}") { _, _ in "" }
        router.get("wildcard/*") { _, _ in "" }
        router.get("recursive_wildcard/**") { _, _ in "" }
        router.patch("/test/longer/path/name") { _, _ in "" }
        let endpoints = router.endpoints
        XCTAssertEqual(endpoints.count, 7)
        XCTAssertEqual(endpoints[0].path.description, "/test")
        XCTAssertEqual(endpoints[0].method, .get)
        XCTAssertEqual(endpoints[1].path.description, "/test")
        XCTAssertEqual(endpoints[1].method, .put)
        XCTAssertEqual(endpoints[2].path.description, "/test/this")
        XCTAssertEqual(endpoints[2].method, .get)
        XCTAssertEqual(endpoints[3].path.description, "/test/longer/path/name")
        XCTAssertEqual(endpoints[3].method, .patch)
        XCTAssertEqual(endpoints[4].path.description, "/{test}/{what}")
        XCTAssertEqual(endpoints[4].method, .post)
        XCTAssertEqual(endpoints[5].path.description, "/wildcard/*")
        XCTAssertEqual(endpoints[5].method, .get)
        XCTAssertEqual(endpoints[6].path.description, "/recursive_wildcard/**")
        XCTAssertEqual(endpoints[6].method, .get)
    }
}

struct TestRouterContext2: RequestContext {
    init(source: Source) {
        self.coreContext = .init(source: source)
        self.string = ""
    }

    /// parameters
    var coreContext: CoreRequestContextStorage

    /// additional data
    var string: String
}
