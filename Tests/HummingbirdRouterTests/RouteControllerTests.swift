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

final class RouteControllerTests: XCTestCase {
    /// Test using a controller inside a router builder.
    func testRouteControllerBody() async throws {
        struct TestController: RouteController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                Get("/test") { _,_ in "xxx" }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            TestController()
        }

        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/test", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "xxx")
            }
        }
    }

    /// Test nesting controllers inside a router builder.
    func testRouteControllerBodyWithNestedControllers() async throws {
        struct ChildAController: RouteController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                RouteGroup("/child_a") {
                    Get { _,_ in "child_a" }
                }
            }
        }

        struct ChildBController: RouteController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                RouteGroup("/child_b") {
                    Get { _,_ in "child_b" }
                }
            }
        }

        struct ParentController: RouteController {
            typealias Context = BasicRouterRequestContext
            var body: some RouterMiddleware<Context> {
                RouteGroup("/parent") {
                    Get { _,_ in return "parent" }
                    ChildAController()
                    ChildBController()
                    Get("child_c") { _,_ in "child_c" }
                }
            }
        }

        let router = RouterBuilder(context: BasicRouterRequestContext.self) {
            ParentController()
        }

        let app = Application(responder: router)

        try await app.test(.router) { client in
            try await client.execute(uri: "/parent", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "parent")
            }
        }

        try await app.test(.router) { client in
            try await client.execute(uri: "/parent/child_a", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "child_a")
            }
        }

        try await app.test(.router) { client in
            try await client.execute(uri: "/parent/child_b", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "child_b")
            }
        }

        try await app.test(.router) { client in
            try await client.execute(uri: "/parent/child_c", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "child_c")
            }
        }
    }
}
