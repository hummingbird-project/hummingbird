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

import HummingbirdTesting
import XCTest

@testable import Hummingbird

final class CookieTests: XCTestCase {
    func testNameValue() {
        let cookie = Cookie(from: "name=value")
        XCTAssertEqual(cookie?.name, "name")
        XCTAssertEqual(cookie?.value, "value")
        XCTAssertEqual(cookie?.description, "name=value")
    }

    func testPropertyOutput() {
        let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.description, "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
    }

    func testExpires() {
        let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.expires, Date(httpHeader: "Wed, 21 Oct 2015 07:28:00 GMT"))
    }

    func testDomain() {
        let cookie = Cookie(from: "name=value; Domain=test.com")
        XCTAssertEqual(cookie?.domain, "test.com")
    }

    func testPath() {
        let cookie = Cookie(from: "name=value; Path=/test")
        XCTAssertEqual(cookie?.path, "/test")
    }

    func testMaxAge() {
        let cookie = Cookie(from: "name=value; Max-Age=3600")
        XCTAssertEqual(cookie?.maxAge, 3600)
    }

    func testSecure() {
        let cookie = Cookie(from: "name=value; Secure")
        XCTAssertEqual(cookie?.secure, true)
    }

    func testHttpOnly() {
        let cookie = Cookie(from: "name=value; HttpOnly")
        XCTAssertEqual(cookie?.httpOnly, true)
    }

    func testSameSite() {
        let cookie = Cookie(from: "name=value; SameSite=Strict")
        XCTAssertEqual(cookie?.sameSite, .strict)
    }

    func testSetCookie() async throws {
        let router = Router()
        router.post("/") { _, _ -> Response in
            var response = Response(status: .ok, headers: [:], body: .init())
            response.setCookie(.init(name: "test", value: "value"))
            return response
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.headers[.setCookie], "test=value; HttpOnly")
            }
        }
    }

    func testSetCookieViaRequest() async throws {
        let router = Router()
        router.post("/") { _, _ in
            EditedResponse(headers: [.setCookie: Cookie(name: "test", value: "value").description], response: "Hello")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.headers[.setCookie], "test=value; HttpOnly")
            }
        }
    }

    func testReadCookieFromRequest() async throws {
        let router = Router()
        router.post("/") { request, _ -> String? in
            request.cookies["test"]?.value
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .post, headers: [.cookie: "test=value"]) { response in
                XCTAssertEqual(String(buffer: response.body), "value")
            }
        }
    }

    func testValidatedCookieSuccess() throws {
        let cookie = try Cookie.validated(name: "session", value: "abcdef1234")
        XCTAssertEqual(cookie.name, "session")
        XCTAssertEqual(cookie.value, "abcdef1234")
        XCTAssertEqual(cookie.httpOnly, true)
        XCTAssertEqual(cookie.secure, false)
    }

    func testValidatedCookieWithSameSite() throws {
        let cookie = try Cookie.validated(name: "foo", value: "bar", sameSite: .strict)
        XCTAssertEqual(cookie.name, "foo")
        XCTAssertEqual(cookie.value, "bar")
        XCTAssertEqual(cookie.sameSite, .strict)
    }

    func testValidatedCookieInvalidName() {
        XCTAssertThrowsError(try Cookie.validated(name: "invalid;name", value: "value")) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        XCTAssertThrowsError(try Cookie.validated(name: "invalid;name", value: "value", sameSite: .strict)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
    }

    func testValidatedCookieInvalidValue() {
        XCTAssertThrowsError(try Cookie.validated(name: "name", value: "inv\u{7F}alid")) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        XCTAssertThrowsError(try Cookie.validated(name: "name", value: "inv\u{7F}alid", sameSite: .strict)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
    }
}
