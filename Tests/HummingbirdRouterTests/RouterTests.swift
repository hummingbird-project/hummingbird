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

import HTTPTypes
import Hummingbird
import HummingbirdRouter
import HummingbirdTesting
import Logging
import NIOCore
import Testing

struct RouterTests {
    struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
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
    @Test func testEndpointPath() async throws {
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("/test/{number}") { _, _ in
                "xxx"
            }
        }
        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/1", method: .get) { response in
                #expect(String(buffer: response.body) == "/test/{number}")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    @Test func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("test") { _, context in
                context.endpointPath
            }
            Get { _, context in
                context.endpointPath
            }
            Post("/test2") { _, context in
                context.endpointPath
            }
        }
        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(String(buffer: response.body) == "/")
            }
            try await client.execute(uri: "/test/", method: .get) { response in
                #expect(String(buffer: response.body) == "/test")
            }
            try await client.execute(uri: "/test2/", method: .post) { response in
                #expect(String(buffer: response.body) == "/test2")
            }
        }
    }

    /// Test endpointPath doesn't have "/" at end
    @Test func testEndpointPathSuffix() async throws {
        struct TestEndpointMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("test/") { _, context in
                context.endpointPath
            }
            Post("test2") { _, context in
                context.endpointPath
            }
            RouteGroup("testGroup") {
                Get { _, context in
                    context.endpointPath
                }
            }
            RouteGroup("testGroup2") {
                Get("/") { _, context in
                    context.endpointPath
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/", method: .get) { response in
                #expect(String(buffer: response.body) == "/test")
            }

            try await client.execute(uri: "/test2/", method: .post) { response in
                #expect(String(buffer: response.body) == "/test2")
            }

            try await client.execute(uri: "/testGroup/", method: .get) { response in
                #expect(String(buffer: response.body) == "/testGroup")
            }

            try await client.execute(uri: "/testGroup2", method: .get) { response in
                #expect(String(buffer: response.body) == "/testGroup2")
            }
        }
    }

    /// Test correct endpoints are called from group
    @Test func testMethodEndpoint() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/endpoint") {
                Get { _, _ in
                    "GET"
                }
                Put { _, _ in
                    "PUT"
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/endpoint", method: .get) { response in
                #expect(String(buffer: response.body) == "GET")
            }

            try await client.execute(uri: "/endpoint", method: .put) { response in
                #expect(String(buffer: response.body) == "PUT")
            }
        }
    }

    /// Test middle in group is applied to group but not to routes outside
    /// group
    @Test func testGroupMiddleware() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Get { _, _ in
                    "hello"
                }
            }
            Get("/not-group") { _, _ in
                "hello"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .get) { response in
                #expect(response.headers[.middleware] == "TestMiddleware")
            }

            try await client.execute(uri: "/not-group", method: .get) { response in
                #expect(response.headers[.middleware] == nil)
            }
        }
    }

    @Test func testEndpointMiddleware() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Head { _, _ in
                    "hello"
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .head) { response in
                #expect(response.headers[.middleware] == "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    @Test func testGroupGroupMiddleware() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/test") {
                TestMiddleware()
                RouteGroup("/group") {
                    Get { _, _ in
                        "hello"
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                #expect(response.headers[.middleware] == "TestMiddleware")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    @Test func testGroupGroupMiddleware2() async throws {
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
                    context.string
                }
                RouteGroup("/group") {
                    TestGroupMiddleware(output: "route2")
                    Get { _, context in
                        context.string
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get) { response in
                #expect(String(buffer: response.body) == "route2")
            }
            try await client.execute(uri: "/test", method: .get) { response in
                #expect(String(buffer: response.body) == "route1")
            }
        }
    }

    /// Test context transform
    @Test func testGroupTransformingGroupMiddleware() async throws {
        struct TestRouterContext2: RequestContext, RouterRequestContext {
            /// router context
            var routerContext: RouterBuilderContext
            /// parameters
            var coreContext: CoreRequestContextStorage
            /// additional data
            var string: String

            typealias Source = BasicRouterRequestContext
            init(source: BasicRouterRequestContext) {
                self.coreContext = .init(source: source)
                self.string = ""
                self.routerContext = source.routerContext
            }
        }
        struct TestTransformMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext2
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string = request.headers[.middleware2] ?? ""
                return try await next(request, context)
            }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            RouteGroup("/test") {
                TestMiddleware()
                RouteGroup("/group") {
                    ContextTransform(to: TestRouterContext2.self) {
                        TestTransformMiddleware()
                        Get { _, context in
                            Response(status: .ok, headers: [.middleware2: context.string])
                        }
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test/group", method: .get, headers: [.middleware2: "Transforming"]) { response in
                #expect(response.headers[.middleware] == "TestMiddleware")
                #expect(response.headers[.middleware2] == "Transforming")
            }
        }
    }

    /// Test throwing context transform
    @Test func testThrowingTransformingGroupMiddleware() async throws {
        struct TestRouterContext: RequestContext, RouterRequestContext {
            /// router context
            var routerContext: RouterBuilderContext
            /// parameters
            var coreContext: CoreRequestContextStorage
            /// additional data
            var string: String?

            init(source: Source) {
                self.coreContext = .init(source: source)
                self.routerContext = .init()
                self.string = nil
            }
        }
        struct TestRouterContext2: RequestContext, RouterRequestContext, ChildRequestContext {
            /// router context
            var routerContext: RouterBuilderContext
            /// parameters
            var coreContext: CoreRequestContextStorage
            /// additional data
            var string: String

            init(context: TestRouterContext) throws {
                self.coreContext = .init(source: context)
                self.routerContext = context.routerContext
                guard let string = context.string else { throw HTTPError(.badRequest) }
                self.string = string
            }
        }
        struct TestTransformMiddleware: RouterMiddleware {
            typealias Context = TestRouterContext
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var context = context
                context.string = request.headers[.middleware2]
                return try await next(request, context)
            }
        }
        let router = RouterBuilder(context: TestRouterContext.self) {
            TestTransformMiddleware()
            RouteGroup("/group", context: TestRouterContext2.self) {
                Get { _, context in
                    Response(status: .ok, headers: [.middleware2: context.string])
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/group", method: .get, headers: [.middleware2: "Transforming"]) { response in
                #expect(response.headers[.middleware2] == "Transforming")
            }
            try await client.execute(uri: "/group", method: .get) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    @Test func testRouteBuilder() async throws {
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
                        context.string
                    }
                }
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/test", method: .get) { response in
                #expect(String(buffer: response.body) == "route1")
            }
            try await client.execute(uri: "/test", method: .post) { response in
                #expect(String(buffer: response.body) == "route2")
            }
        }
    }

    /// Test the hummingbird core parser against possible overflows of the percent encoder. this issue was introduced in pr #404 in the context of query parameters but I've thrown in some other random overflow scenarios in here too for good measure. if it doesn't crash, its a win.
    @Test func testQueryParameterOverflow() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("overflow") { req, _ in
                let currentQP = req.uri.queryParameters["query"]
                return String("\(currentQP ?? "")")
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/overflow?query=value%", method: .get) { response in
                #expect(String(buffer: response.body) == "value%")
            }
            try await client.execute(uri: "/overflow?query%=value%", method: .get) { response in
                #expect(String(buffer: response.body) == "")
            }
            try await client.execute(uri: "/overflow?%&", method: .get) { response in
                #expect(String(buffer: response.body) == "")
            }
        }
    }

    @Test func testParameters() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Delete("/user/:id") { _, context -> String? in
                context.parameters.get("id")
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/1234", method: .delete) { response in
                #expect(String(buffer: response.body) == "1234")
            }
        }
    }

    @Test func testParametersAs() async throws {
        enum TestEnumString: String {  // for RawRepresentable
            case hummingbird
        }
        enum TestEnumLosslessStringConvertible: LosslessStringConvertible {
            case hummingbird
            init?(_ description: String) {
                if description == "hummingbird" {
                    self = .hummingbird
                } else {
                    return nil
                }
            }
            var description: String { "hummingbird" }
        }
        enum TestEnumBoth: String, LosslessStringConvertible {
            case hummingbird
            init?(_ description: String) {
                if description == "hummingbird" {
                    self = .hummingbird
                } else {
                    return nil
                }
            }
            var description: String { "hummingbird" }
        }
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("/stringoptional/:id") { _, context -> String? in
                context.parameters.get("id", as: String.self)
            }
            Get("/string/:id") { _, context throws -> String in
                try context.parameters.require("id", as: String.self)
            }
            Get("/enumstring/:id") { _, context throws -> String in
                (try context.parameters.require("id", as: TestEnumString.self)).rawValue
            }
            Get("/enumlosslessstringconvertible/:id") { _, context throws -> String in
                (try context.parameters.require("id", as: TestEnumLosslessStringConvertible.self)).description
            }
            Get("/enumboth/:id") { _, context throws -> String in
                // this fails as `- error: ambiguous use of 'require(_:as:)'` without the @_disfavoredOverload
                (try context.parameters.require("id", as: TestEnumBoth.self)).description
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/stringoptional/1234", method: .get) { response in
                #expect(String(buffer: response.body) == "1234")
            }
            try await client.execute(uri: "/string/1234", method: .get) { response in
                #expect(String(buffer: response.body) == "1234")
            }
            try await client.execute(uri: "/enumstring/hummingbird", method: .get) { response in
                #expect(String(buffer: response.body) == "hummingbird")
            }
            try await client.execute(uri: "/enumstring/swiftbird", method: .get) { response in
                #expect(response.status == .badRequest)
            }
            try await client.execute(uri: "/enumlosslessstringconvertible/hummingbird", method: .get) { response in
                #expect(String(buffer: response.body) == "hummingbird")
            }
            try await client.execute(uri: "/enumboth/hummingbird", method: .get) { response in
                #expect(String(buffer: response.body) == "hummingbird")
            }
        }
    }

    @Test func testParameterCollection() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Delete("/user/:username/:id") { _, context -> String? in
                #expect(context.parameters.count == 2)
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/user/john/1234", method: .delete) { response in
                #expect(String(buffer: response.body) == "1234")
            }
        }
    }

    @Test func testPartialCapture() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Route(.get, "/files/file.{ext}/{name}.jpg") { _, context -> String in
                #expect(context.parameters.count == 2)
                let ext = try context.parameters.require("ext")
                let name = try context.parameters.require("name")
                return "\(name).\(ext)"
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                #expect(String(buffer: response.body) == "test.doc")
            }
        }
    }

    @Test func testPartialWildcard() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("/files/file.*/*.jpg") { _, _ -> HTTPResponse.Status in
                .ok
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/files/file.doc/test.png", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    /// Test we have a request id and that it increments with each request
    @Test func testRequestId() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("id") { _, context in
                context.id.description
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            let id = try await client.execute(uri: "/id", method: .get) { response -> String in
                String(buffer: response.body)
            }
            try await client.execute(uri: "/id", method: .get) { response in
                let id2 = String(buffer: response.body)
                #expect(id2 != id)
            }
        }
    }

    // Test redirect response
    @Test func testRedirect() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("redirect") { _, _ in
                Response.redirect(to: "/other")
            }
        }
        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/redirect", method: .get) { response in
                #expect(response.headers[.location] == "/other")
                #expect(response.status == .seeOther)
            }
        }
    }

    @Test func testResponderBuilder() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            Get("hello") { _, _ in
                "hello"
            }
        }
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "hello")
            }
        }
    }

    // Test case insensitive router works
    @Test func testCaseInsensitive() async throws {
        let router = RouterBuilder(context: BasicRouterRequestContext.self, options: .caseInsensitive) {
            Get("Uppercased") { _, _ in
                HTTPResponse.Status.ok
            }
            Get("lowercased") { _, _ in
                HTTPResponse.Status.ok
            }
            RouteGroup("group") {
                Get("Uppercased") { _, _ in
                    HTTPResponse.Status.ok
                }
            }
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/uppercased", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/LOWERCASED", method: .get) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(uri: "/Group/uppercased", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }
}

public struct TestRouterContext2: RouterRequestContext, RequestContext {
    /// router context
    public var routerContext: RouterBuilderContext
    /// core context
    public var coreContext: CoreRequestContextStorage

    /// additional data
    public var string: String

    public init(source: Source) {
        self.routerContext = .init()
        self.coreContext = .init(source: source)
        self.string = ""
    }
}
