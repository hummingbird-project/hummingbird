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
import HummingbirdXCT
import XCTest
/*
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

    func testSetCookie() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.post("/") { _, _ -> HBResponse in
            var response = HBResponse(status: .ok, headers: [:], body: .init())
            response.setCookie(.init(name: "test", value: "value"))
            return response
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .POST) { response in
                XCTAssertEqual(response.headers["Set-Cookie"].first, "test=value; HttpOnly")
            }
        }
    }

    func testSetCookieViaRequest() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.post("/") { _, _ in
            return HBEditedResponse(headers: ["Set-Cookie": HBCookie(name: "test", value: "value").description], response: "Hello")
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .POST) { response in
                XCTAssertEqual(response.headers["Set-Cookie"].first, "test=value; HttpOnly")
            }
        }
    }

    func testReadCookieFromRequest() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.post("/") { request, _ -> String? in
            return request.cookies["test"]?.value
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .POST, headers: ["cookie": "test=value"]) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(String(buffer: body), "value")
            }
        }
    }
}
*/