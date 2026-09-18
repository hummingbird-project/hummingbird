//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import HummingbirdTesting
import Testing

@testable import Hummingbird

extension HTTPTests {
    struct CookieTests {
        @available(hummingbird 3.0, *)
        @Test func testNameValue() {
            let cookie = Cookie(from: "name=value")
            #expect(cookie?.name == "name")
            #expect(cookie?.value == "value")
            #expect(cookie?.description == "name=value")
        }

        @available(hummingbird 3.0, *)
        @Test func testPropertyOutput() {
            let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
            #expect(cookie?.description == "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        }

        @available(hummingbird 3.0, *)
        @Test func testExpires() {
            let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
            #expect(cookie?.expires == Date(httpHeader: "Wed, 21 Oct 2015 07:28:00 GMT"))
        }

        @available(hummingbird 3.0, *)
        @Test func testDomain() {
            let cookie = Cookie(from: "name=value; Domain=test.com")
            #expect(cookie?.domain == "test.com")
        }

        @available(hummingbird 3.0, *)
        @Test func testPath() {
            let cookie = Cookie(from: "name=value; Path=/test")
            #expect(cookie?.path == "/test")
        }

        @available(hummingbird 3.0, *)
        @Test func testMaxAge() {
            let cookie = Cookie(from: "name=value; Max-Age=3600")
            #expect(cookie?.maxAge == 3600)
        }

        @available(hummingbird 3.0, *)
        @Test func testSecure() {
            let cookie = Cookie(from: "name=value; Secure")
            #expect(cookie?.secure == true)
        }

        @available(hummingbird 3.0, *)
        @Test func testHttpOnly() {
            let cookie = Cookie(from: "name=value; HttpOnly")
            #expect(cookie?.httpOnly == true)
        }

        @available(hummingbird 3.0, *)
        @Test func testSameSite() {
            let cookie = Cookie(from: "name=value; SameSite=Strict")
            #expect(cookie?.sameSite == .strict)
        }

        @available(hummingbird 3.0, *)
        @Test func testSingleRequestCookie() throws {
            let cookies = Cookies(from: ["name=value"])
            let cookie = try #require(cookies["name"])
            #expect(cookie.value == "value")
        }

        @available(hummingbird 3.0, *)
        @Test func testMultipleRequestCookie() throws {
            let cookies = Cookies(from: ["name=value; name2=value2"])
            let cookie = try #require(cookies["name"])
            #expect(cookie.value == "value")
            let cookie2 = try #require(cookies["name2"])
            #expect(cookie2.value == "value2")
        }

        @available(hummingbird 3.0, *)
        @Test func testMultipleHeadersRequestCookie() throws {
            let cookies = Cookies(from: ["name=value; name2=value2", "name3=value3"])
            let cookie = try #require(cookies["name"])
            #expect(cookie.value == "value")
            let cookie2 = try #require(cookies["name2"])
            #expect(cookie2.value == "value2")
            let cookie3 = try #require(cookies["name3"])
            #expect(cookie3.value == "value3")
        }

        @available(hummingbird 3.0, *)
        @Test func testSetCookie() async throws {
            let router = Router()
            router.post("/") { _, _ -> Response in
                var response = Response(status: .ok, headers: [:], body: .init())
                response.setCookie(.init(name: "test", value: "value"))
                return response
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/", method: .post) { response in
                    #expect(response.headers[.setCookie] == "test=value; HttpOnly")
                }
            }
        }

        @available(hummingbird 3.0, *)
        @Test func testSetCookieViaRequest() async throws {
            let router = Router()
            router.post("/") { _, _ in
                EditedResponse(headers: [.setCookie: Cookie(name: "test", value: "value").description], response: "Hello")
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/", method: .post) { response in
                    #expect(response.headers[.setCookie] == "test=value; HttpOnly")
                }
            }
        }

        @available(hummingbird 3.0, *)
        @Test func testReadCookieFromRequest() async throws {
            let router = Router()
            router.post("/") { request, _ -> String? in
                request.cookies["test"]?.value
            }
            let app = Application(responder: router.buildResponder())
            try await app.test(.router) { client in
                try await client.execute(uri: "/", method: .post, headers: [.cookie: "test=value"]) { response in
                    #expect(String(buffer: response.body) == "value")
                }
            }
        }
    }

    @available(hummingbird 3.0, *)
    @Test func testValidatedCookieSuccess() throws {
        let cookie = try Cookie.validated(name: "session", value: "abcdef1234")
        #expect(cookie.name == "session")
        #expect(cookie.value == "abcdef1234")
        #expect(cookie.httpOnly == true)
        #expect(cookie.secure == false)
    }

    @available(hummingbird 3.0, *)
    @Test func testValidatedCookieWithSameSite() throws {
        let cookie = try Cookie.validated(name: "foo", value: "bar", sameSite: .strict)
        #expect(cookie.name == "foo")
        #expect(cookie.value == "bar")
        #expect(cookie.sameSite == .strict)
    }

    @available(hummingbird 3.0, *)
    @Test func testValidatedCookieInvalidName() {
        #expect(throws: Cookie.ValidationError.self) {
            try Cookie.validated(name: "invalid;name", value: "value")
        }
        #expect(throws: Cookie.ValidationError.self) {
            try Cookie.validated(name: "invalid;name", value: "value", sameSite: .strict)
        }
    }

    @available(hummingbird 3.0, *)
    @Test func testValidatedCookieInvalidValue() {
        #expect(throws: Cookie.ValidationError.self) {
            try Cookie.validated(name: "name", value: "inv\u{7F}alid")
        }
        #expect(throws: Cookie.ValidationError.self) {
            try Cookie.validated(name: "name", value: "inv\u{7F}alid", sameSite: .strict)
        }
    }
}
