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

@testable import HummingbirdFoundation
import XCTest

class CookieTests: XCTestCase {
    func testNameValue() {
        let cookie = HBCookie(from: "name=value")
        XCTAssertEqual(cookie?.name, "name")
        XCTAssertEqual(cookie?.value, "value")
        XCTAssertEqual(cookie?.description, "name=value")
    }

    func testPropertyOutput() {
        let cookie = HBCookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.description, "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
    }

    func testExpires() {
        let cookie = HBCookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.expires, HBDateCache.rfc1123Formatter.date(from: "Wed, 21 Oct 2015 07:28:00 GMT"))
    }

    func testDomain() {
        let cookie = HBCookie(from: "name=value; Domain=test.com")
        XCTAssertEqual(cookie?.domain, "test.com")
    }

    func testPath() {
        let cookie = HBCookie(from: "name=value; Path=/test")
        XCTAssertEqual(cookie?.path, "/test")
    }

    func testMaxAge() {
        let cookie = HBCookie(from: "name=value; Max-Age=3600")
        XCTAssertEqual(cookie?.maxAge, 3600)
    }

    func testSecure() {
        let cookie = HBCookie(from: "name=value; Secure")
        XCTAssertEqual(cookie?.secure, true)
    }

    func testHttpOnly() {
        let cookie = HBCookie(from: "name=value; HttpOnly")
        XCTAssertEqual(cookie?.httpOnly, true)
    }

    func testSameSite() {
        let cookie = HBCookie(from: "name=value; SameSite=Secure")
        XCTAssertEqual(cookie?.sameSite, .secure)
    }

    func testSetCookie() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/") { _ -> HBResponse in
            let response = HBResponse(status: .ok, headers: [:], body: .empty)
            response.setCookie(.init(name: "test", value: "value"))
            return response
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .POST) { response in
            XCTAssertEqual(response.headers["Set-Cookie"].first, "test=value; HttpOnly")
        }
    }

    func testSetCookieViaRequest() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/") { request -> String in
            request.response.setCookie(.init(name: "test", value: "value"))
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .POST) { response in
            XCTAssertEqual(response.headers["Set-Cookie"].first, "test=value; HttpOnly")
        }
    }

    func testReadCookieFromRequest() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/") { request -> String? in
            return request.cookies["test"]?.value
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/", method: .POST, headers: ["cookie": "test=value"]) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "value")
        }
    }
}
