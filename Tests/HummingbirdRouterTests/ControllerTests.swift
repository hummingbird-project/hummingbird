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
import XCTest

final class ControllerTests: XCTestCase {
    func testRouterControllerWithSingleRoute() async throws {
        struct TestController: RouterController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                Get("foo") { _, _ in "foo" }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestController()
        }

        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/foo", method: .get) {
                XCTAssertEqual(String(buffer: $0.body), "foo")
            }
        }
    }

    func testRouterControllerWithMultipleRoutes() async throws {
        struct TestController: RouterController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                Get("foo") { _, _ in "foo" }
                Get("bar") { _, _ in "bar" }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestController()
        }

        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/foo", method: .get) {
                XCTAssertEqual(String(buffer: $0.body), "foo")
            }

            try await client.execute(uri: "/bar", method: .get) {
                XCTAssertEqual(String(buffer: $0.body), "bar")
            }
        }
    }

    func testRouterControllerWithGenericChildren() async throws {
        struct ChildController: RouterController {
            typealias Context = BasicRouterRequestContext
            let name: String
            var body: some RouterMiddleware<Context> {
                Get("child_\(self.name)") { _, _ in "child_\(self.name)" }
            }
        }

        struct ParentController<Context: RouterRequestContext, Child: RouterMiddleware>: RouterController where Child.Context == Context {
            var child: Child

            init(@MiddlewareFixedTypeBuilder<Request, Response, Context> _ child: () -> Child) {
                self.child = child()
            }

            var body: some RouterMiddleware<Context> {
                RouteGroup("parent") {
                    self.child
                }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            ParentController {
                Get("child_a") { _, _ in "child_a" }
                ChildController(name: "b")
                ChildController(name: "c")
                Get("child_d") { _, _ in "child_d" }
            }
        }

        let app = Application(responder: router)
        try await app.test(.router) { client in
            for letter in "abcd" {
                try await client.execute(uri: "/parent/child_\(letter)", method: .get) {
                    XCTAssertEqual(String(buffer: $0.body), "child_\(letter)")
                }
            }
        }
    }

    func testRouterControllerWithMiddleware() async throws {
        struct TestMiddleware<Context: RequestContext>: RouterMiddleware {
            func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
                var response = try await next(request, context)
                response.headers[.middleware] = "TestMiddleware"
                return response
            }
        }

        struct ChildController: RouterController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                Get("foo") { _, _ in "foo" }
            }
        }

        struct ParentController: RouterController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                RouteGroup("parent") {
                    TestMiddleware()
                    ChildController()
                    Get("bar") { _, _ in "bar" }
                }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            ParentController()
        }

        let app = Application(responder: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "/parent/foo", method: .get) {
                XCTAssertEqual($0.headers[.middleware], "TestMiddleware")
                XCTAssertEqual(String(buffer: $0.body), "foo")
            }

            try await client.execute(uri: "/parent/bar", method: .get) {
                XCTAssertEqual($0.headers[.middleware], "TestMiddleware")
                XCTAssertEqual(String(buffer: $0.body), "bar")
            }
        }
    }
}
