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
    func testNameValue() throws {
        let cookie = try Cookie(from: "name=value")
        XCTAssertEqual(cookie?.name, "name")
        XCTAssertEqual(cookie?.value, "value")
        XCTAssertEqual(cookie?.description, "name=value")
    }

    func testPropertyOutput() throws {
        let cookie = try Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.description, "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
    }

    func testExpires() throws {
        let cookie = try Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        XCTAssertEqual(cookie?.expires, Date(httpHeader: "Wed, 21 Oct 2015 07:28:00 GMT"))
    }

    func testDomain() throws {
        let cookie = try Cookie(from: "name=value; Domain=test.com")
        XCTAssertEqual(cookie?.domain, "test.com")
    }

    func testPath() throws {
        let cookie = try Cookie(from: "name=value; Path=/test")
        XCTAssertEqual(cookie?.path, "/test")
    }

    func testMaxAge() throws {
        let cookie = try Cookie(from: "name=value; Max-Age=3600")
        XCTAssertEqual(cookie?.maxAge, 3600)
    }

    func testSecure() throws {
        let cookie = try Cookie(from: "name=value; Secure")
        XCTAssertEqual(cookie?.secure, true)
    }

    func testHttpOnly() throws {
        let cookie = try Cookie(from: "name=value; HttpOnly")
        XCTAssertEqual(cookie?.httpOnly, true)
    }

    func testSameSite() throws {
        let cookie = try Cookie(from: "name=value; SameSite=Strict")
        XCTAssertEqual(cookie?.sameSite, .strict)
    }

    func testSetCookie() async throws {
        let router = Router()
        router.post("/") { _, _ -> Response in
            var response = Response(status: .ok, headers: [:], body: .init())
            response.setCookie(try .init(name: "test", value: "value", validate: true))
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
        router.post("/") { _, _ throws in
            EditedResponse(headers: [.setCookie: try Cookie(name: "test", value: "value", validate: true).description], response: "Hello")
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
            try await client.execute(uri: "/", method: .post, headers: [.cookie: try Cookie(name: "test", value: "invalid\"value", validate: false).description]) { response in
                XCTAssertEqual(String(buffer: response.body), "invalid\"value")
            }
        }
    }

    func testValidatedCookieSuccess() throws {
        let cookie = try Cookie(name: "session", value: "abcdef1234", validate: true)
        XCTAssertEqual(cookie.name, "session")
        XCTAssertEqual(cookie.value, "abcdef1234")
        XCTAssertEqual(cookie.httpOnly, true)
        XCTAssertEqual(cookie.secure, false)
    }

    func testValidatedCookieWithSameSite() throws {
        let cookie = try Cookie(name: "foo", value: "bar", validate: true, sameSite: .strict)
        XCTAssertEqual(cookie.name, "foo")
        XCTAssertEqual(cookie.value, "bar")
        XCTAssertEqual(cookie.sameSite, .strict)
    }

    func testValidatedCookieInvalidName() throws {
        XCTAssertThrowsError(try Cookie(name: "invalid;name", value: "value", validate: true)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        XCTAssertThrowsError(try Cookie(name: "invalid;name", value: "value", validate: true, sameSite: .strict)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        let invalidNameCookie = try Cookie(name: "invalid\"name", value: "value", validate: false)
        XCTAssert(invalidNameCookie.name == "invalid\"name")
        XCTAssertEqual(invalidNameCookie.valid, false)
        let invalidNameSameSiteCookie = try Cookie(name: "invalid\"name", value: "value", validate: false, sameSite: .strict)
        XCTAssert(invalidNameSameSiteCookie.name == "invalid\"name")
        XCTAssertEqual(invalidNameSameSiteCookie.valid, false)
    }

    func testValidatedCookieInvalidValue() throws {
        XCTAssertThrowsError(try Cookie(name: "name", value: "inv\u{7F}alid", validate: true)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        XCTAssertThrowsError(try Cookie(name: "name", value: "inv\u{7F}alid", validate: true, sameSite: .strict)) { error in
            XCTAssert(error is Cookie.ValidationError, "Unexpected error type")
        }
        let invalidValueCookie = try Cookie(name: "name", value: "invalid\"value", validate: false)
        XCTAssert(invalidValueCookie.value == "invalid\"value")
        XCTAssertEqual(invalidValueCookie.valid, false)
        let invalidValueSameSiteCookie = try Cookie(name: "name", value: "invalid\"value", validate: false, sameSite: .strict)
        XCTAssert(invalidValueSameSiteCookie.value == "invalid\"value")
        XCTAssertEqual(invalidValueSameSiteCookie.valid, false)
    }
}
