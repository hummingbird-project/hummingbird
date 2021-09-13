//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import HummingbirdXCT
import XCTest

final class RouterTests: XCTestCase {
    struct TestMiddleware: HBMiddleware {
        func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
            return next.respond(to: request).map { response in
                var response = response
                response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                return response
            }
        }
    }

    func testEndpoint() throws {
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

        app.XCTExecute(uri: "/endpoint", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }

        app.XCTExecute(uri: "/endpoint", method: .PUT) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "PUT")
        }
    }

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

        app.XCTExecute(uri: "/group", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }

        app.XCTExecute(uri: "/not-group", method: .GET) { response in
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

        app.XCTExecute(uri: "/group", method: .HEAD) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

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

        app.XCTExecute(uri: "/test/group", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
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

        app.XCTExecute(uri: "/user/1234", method: .DELETE) { response in
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

        app.XCTExecute(uri: "/user/john/1234", method: .DELETE) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "1234")
        }
    }
}
