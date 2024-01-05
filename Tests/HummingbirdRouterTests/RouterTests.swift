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
import HummingbirdXCT
import Logging
import NIOCore
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
        let output: String

        init(_ output: String = "TestMiddleware") {
            self.output = output
        }

        func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
            var response = try await next(request, context)
            response.headers[.middleware] = self.output
            return response
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() async throws {
        struct TestEndpointMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            TestEndpointMiddleware()
            Get("/test/{number}") { _, _ in
                return "xxx"
            }
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test/1", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test/{number}")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                _ = try await next(request, context)
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
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
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/")
            }
            try await client.XCTExecute(uri: "/test/", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test")
            }
            try await client.XCTExecute(uri: "/test2/", method: .post) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test2")
            }
        }
    }

    /// Test endpointPath doesn't have "/" at end
    func testEndpointPathSuffix() async throws {
        struct TestEndpointMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                guard let endpointPath = context.endpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
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
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test/", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test")
            }

            try await client.XCTExecute(uri: "/test2/", method: .post) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test2")
            }

            try await client.XCTExecute(uri: "/testGroup/", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/testGroup")
            }

            try await client.XCTExecute(uri: "/testGroup2", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/testGroup2")
            }
        }
    }

    /// Test correct endpoints are called from group
    func testMethodEndpoint() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            RouteGroup("/endpoint") {
                Get { _, _ in
                    return "GET"
                }
                Put { _, _ in
                    return "PUT"
                }
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/endpoint", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "GET")
            }

            try await client.XCTExecute(uri: "/endpoint", method: .put) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "PUT")
            }
        }
    }

    /// Test middle in group is applied to group but not to routes outside
    /// group
    func testGroupMiddleware() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
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
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }

            try await client.XCTExecute(uri: "/not-group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], nil)
            }
        }
    }

    func testEndpointMiddleware() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Head { _, _ in
                    return "hello"
                }
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/group", method: .head) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            RouteGroup("/test") {
                TestMiddleware()
                RouteGroup("/group") {
                    Get { _, _ in
                        return "hello"
                    }
                }
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test/group", method: .get) { response in
                XCTAssertEqual(response.headers[.middleware], "TestMiddleware")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() async throws {
        struct TestGroupMiddleware: HBMiddlewareProtocol {
            typealias Context = HBTestRouterContext2
            let output: String

            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                var context = context
                context.string = self.output
                return try await next(request, context)
            }
        }

        let router = HBRouterBuilder(context: HBTestRouterContext2.self) {
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
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test/group", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route2")
            }
            try await client.XCTExecute(uri: "/test", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route1")
            }
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testRouteBuilder() async throws {
        struct TestGroupMiddleware: HBMiddlewareProtocol {
            typealias Context = HBTestRouterContext2
            let output: String

            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                var context = context
                context.string += self.output
                return try await next(request, context)
            }
        }

        @Sendable func handle(_: HBRequest, _ context: HBTestRouterContext2) async throws -> String {
            context.string
        }
        let router = HBRouterBuilder(context: HBTestRouterContext2.self) {
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
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route1")
            }
            try await client.XCTExecute(uri: "/test", method: .post) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route2")
            }
        }
    }

    func testParameters() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Delete("/user/:id") { _, context -> String? in
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user/1234", method: .delete) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testParameterCollection() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Delete("/user/:username/:id") { _, context -> String? in
                XCTAssertEqual(context.parameters.count, 2)
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user/john/1234", method: .delete) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testPartialCapture() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Get("/files/file.{ext}/{name}.jpg") { _, context -> String in
                XCTAssertEqual(context.parameters.count, 2)
                let ext = try context.parameters.require("ext")
                let name = try context.parameters.require("name")
                return "\(name).\(ext)"
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "test.doc")
            }
        }
    }

    func testPartialWildcard() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Get("/files/file.*/*.jpg") { _, _ -> HTTPResponse.Status in
                return .ok
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/files/file.doc/test.jpg", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
            }
            try await client.XCTExecute(uri: "/files/file.doc/test.png", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    /// Test we have a request id and that it increments with each request
    func testRequestId() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Get("id") { _, context in
                return context.id.description
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            let id = try await client.XCTExecute(uri: "/id", method: .get) { response -> String in
                let body = try XCTUnwrap(response.body)
                return String(buffer: body)
            }
            try await client.XCTExecute(uri: "/id", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                let id2 = String(buffer: body)
                XCTAssertNotEqual(id2, id)
            }
        }
    }

    // Test redirect response
    func testRedirect() async throws {
        let router = HBRouterBuilder(context: HBBasicRouterRequestContext.self) {
            Get("redirect") { _, _ in
                return HBResponse.redirect(to: "/other")
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/redirect", method: .get) { response in
                XCTAssertEqual(response.headers[.location], "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }
}

public struct HBTestRouterContext2: HBRouterRequestContext, HBRequestContext {
    /// router context
    public var routerContext: HBRouterBuilderContext
    /// core context
    public var coreContext: HBCoreRequestContext
    /// Connected remote host
    public var remoteAddress: SocketAddress? { nil }

    /// additional data
    public var string: String

    public init(allocator: ByteBufferAllocator, logger: Logger) {
        self.routerContext = .init()
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.string = ""
    }
}
