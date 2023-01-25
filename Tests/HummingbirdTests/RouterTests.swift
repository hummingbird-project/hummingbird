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

        func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
            return next.respond(to: request).map { response in
                var response = response
                response.headers.replaceOrAdd(name: "middleware", value: self.output)
                return response
            }
        }
    }

    /// Test endpointPath is set
    func testEndpointPath() throws {
        struct TestEndpointMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                guard let endpointPath = request.endpointPath else { return next.respond(to: request) }
                return request.success(.init(status: .ok, body: .byteBuffer(ByteBuffer(string: endpointPath))))
            }
        }

        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestEndpointMiddleware())
        app.router.get("/test/:number") { _ in return "xxx" }

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/test/1", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "/test/:number")
        }
    }

    /// Test endpointPath is prefixed with a "/"
    func testEndpointPathPrefix() throws {
        struct TestEndpointMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                guard let endpointPath = request.endpointPath else { return next.respond(to: request) }
                return request.success(.init(status: .ok, body: .byteBuffer(ByteBuffer(string: endpointPath))))
            }
        }

        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestEndpointMiddleware())
        app.router.get("test") {
            $0.endpointPath
        }
        app.router.post("/test2") {
            $0.endpointPath
        }

        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/test/", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "/test")
        }

        try app.XCTExecute(uri: "/test2/", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "/test2")
        }
    }

    /// Test correct endpoints are called from group
    func testMethodEndpoint() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/endpoint")
            .get { _ in
                return "GET"
            }
            .put { _ in
                return "PUT"
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/endpoint", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }

        try app.XCTExecute(uri: "/endpoint", method: .PUT) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "PUT")
        }
    }

    /// Test middle in group is applied to group but not to routes outside
    /// group
    func testGroupMiddleware() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group()
            .add(middleware: TestMiddleware())
            .get("/group") { _ in
                return "hello"
            }
        app.router.get("/not-group") { _ in
            return "hello"
        }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/group", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }

        try app.XCTExecute(uri: "/not-group", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, nil)
        }
    }

    func testEndpointMiddleware() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/group")
            .add(middleware: TestMiddleware())
            .head { _ in
                return "hello"
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/group", method: .HEAD) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    /// Test middleware in parent group is applied to routes in child group
    func testGroupGroupMiddleware() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/test")
            .add(middleware: TestMiddleware())
            .group("/group")
            .get { request in
                return request.success("hello")
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/test/group", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    /// Test adding middleware to group doesn't affect middleware in parent groups
    func testGroupGroupMiddleware2() throws {
        struct TestGroupMiddleware: HBMiddleware {
            let output: String

            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                var request = request
                request.string = self.output
                return next.respond(to: request)
            }
        }

        let app = HBApplication(testing: .embedded)
        app.router
            .group("/test")
            .add(middleware: TestGroupMiddleware(output: "route1"))
            .get { request in
                return request.success(request.string)
            }
            .group("/group")
            .add(middleware: TestGroupMiddleware(output: "route2"))
            .get { request in
                return request.success(request.string)
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/test/group", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "route2")
        }
        try app.XCTExecute(uri: "/test", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "route1")
        }
    }

    func testParameters() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .delete("/user/:id") { request -> String? in
                return request.parameters.get("id", as: String.self)
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/user/1234", method: .DELETE) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "1234")
        }
    }

    func testParameterCollection() throws {
        let app = HBApplication(testing: .embedded)
        app.router
            .delete("/user/:username/:id") { request -> String? in
                XCTAssertEqual(request.parameters.count, 2)
                return request.parameters.get("id", as: String.self)
            }
        try app.XCTStart()
        defer { app.XCTStop() }

        try app.XCTExecute(uri: "/user/john/1234", method: .DELETE) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "1234")
        }
    }
}

extension HBRequest {
    var string: String {
        get { self.extensions.get(\.string) }
        set { self.extensions.set(\.string, value: newValue) }
    }
}
