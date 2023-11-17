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
import HummingbirdXCT
import Logging
import NIOCore
import Tracing
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware<Context: HBRequestContext>: HBMiddlewareProtocol {
        let output: String

        init(_ output: String = "TestMiddleware") {
            self.output = output
        }

        func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
            var response = try await next(request, context)
            response.headers.replaceOrAdd(name: "middleware", value: self.output)
            return response
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() async throws {
        struct TestEndpointMiddleware<Context: HBRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                _ = try await next(request, context)
                guard let endpointPath = context.resolvedEndpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self) {
            TestEndpointMiddleware()
            Get("/test/:number") { _, _ in
                return "xxx"
            }
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test/1", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "/test/${number}")
            }
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() async throws {
        struct TestEndpointMiddleware<Context: HBRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                _ = try await next(request, context)
                guard let endpointPath = context.resolvedEndpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self) {
            TestEndpointMiddleware()
            Get("test") { _, context in
                return context.resolvedEndpointPath
            }
            Get { _, context in
                return context.resolvedEndpointPath
            }
            Post("/test2") { _, context in
                return context.resolvedEndpointPath
            }
        }
        let app = HBApplication(responder: router)

        try await app.test(.router) { client in
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
        struct TestEndpointMiddleware<Context: HBRequestContext>: HBMiddlewareProtocol {
            func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
                guard let endpointPath = context.resolvedEndpointPath else { return try await next(request, context) }
                return .init(status: .ok, body: .init(byteBuffer: ByteBuffer(string: endpointPath)))
            }
        }

        let router = HBRouter(context: HBTestRouterContext.self) {
            TestEndpointMiddleware()
            Get("test/") { _, context in
                return context.resolvedEndpointPath
            }
            Post("test2") { _, context in
                return context.resolvedEndpointPath
            }
            RouteGroup("testGroup") {
                Get { _, context in
                    return context.resolvedEndpointPath
                }
            }
            RouteGroup("testGroup2") {
                Get("/") { _, context in
                    return context.resolvedEndpointPath
                }
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
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
        let router = HBRouter(context: HBTestRouterContext.self) {
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
        let router = HBRouter(context: HBTestRouterContext.self) {
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
            try await client.XCTExecute(uri: "/group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }

            try await client.XCTExecute(uri: "/not-group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, nil)
            }
        }
    }

    func testEndpointMiddleware() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
            RouteGroup("/group") {
                TestMiddleware()
                Head { _, _ in
                    return "hello"
                }
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/group", method: .HEAD) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
            }
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
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
            try await client.XCTExecute(uri: "/test/group", method: .GET) { response in
                XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
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

        let router = HBRouter(context: HBTestRouterContext2.self) {
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

        @Sendable func handle(_ request: HBRequest, _ context: HBTestRouterContext2) async throws -> String {
            context.string
        }
        let router = HBRouter(context: HBTestRouterContext2.self) {
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
            try await client.XCTExecute(uri: "/test", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route1")
            }
            try await client.XCTExecute(uri: "/test", method: .POST) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "route2")
            }
        }
    }

    func testParameters() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
            Delete("/user/:id") { _, context -> String? in
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user/1234", method: .DELETE) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testParameterCollection() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
            Delete("/user/:username/:id") { _, context -> String? in
                XCTAssertEqual(context.parameters.count, 2)
                return context.parameters.get("id", as: String.self)
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user/john/1234", method: .DELETE) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "1234")
            }
        }
    }

    func testPartialCapture() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
            Get("/files/file.${ext}/${name}.jpg") { _, context -> String in
                XCTAssertEqual(context.parameters.count, 2)
                let ext = try context.parameters.require("ext")
                let name = try context.parameters.require("name")
                return "\(name).\(ext)"
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/files/file.doc/test.jpg", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "test.doc")
            }
        }
    }

    func testPartialWildcard() async throws {
        let router = HBRouter(context: HBTestRouterContext.self) {
            Get("/files/file.*/*.jpg") { _, _ -> HTTPResponseStatus in
                return .ok
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
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
        let router = HBRouter(context: HBTestRouterContext.self) {
            Get("id") { _, context in
                return context.id.description
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
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
        let router = HBRouter(context: HBTestRouterContext.self) {
            Get("redirect") { _, _ in
                return HBResponse.redirect(to: "/other")
            }
        }
        let app = HBApplication(responder: router)
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/redirect", method: .GET) { response in
                XCTAssertEqual(response.headers["location"].first, "/other")
                XCTAssertEqual(response.status, .seeOther)
            }
        }
    }
}

public struct HBTestRouterContext2: HBTestRouterContextProtocol {
    public init(applicationContext: HBApplicationContext, eventLoop: EventLoop, logger: Logger) {
        self.coreContext = .init(applicationContext: applicationContext, eventLoop: eventLoop, logger: logger)
        self.string = ""
    }

    /// parameters
    public var coreContext: HBCoreRequestContext
    /// Connected remote host
    public var remoteAddress: SocketAddress? { nil }

    /// additional data
    public var string: String
}
