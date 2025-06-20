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

import Foundation
import HummingbirdTesting
import Testing

@testable import Hummingbird

extension HTTPTests {
    struct CookieTests {
        @Test func testNameValue() {
            let cookie = Cookie(from: "name=value")
            #expect(cookie?.name == "name")
            #expect(cookie?.value == "value")
            #expect(cookie?.description == "name=value")
        }

        @Test func testPropertyOutput() {
            let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
            #expect(cookie?.description == "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
        }

        @Test func testExpires() {
            let cookie = Cookie(from: "name=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT")
            #expect(cookie?.expires == Date(httpHeader: "Wed, 21 Oct 2015 07:28:00 GMT"))
        }

        @Test func testDomain() {
            let cookie = Cookie(from: "name=value; Domain=test.com")
            #expect(cookie?.domain == "test.com")
        }

        @Test func testPath() {
            let cookie = Cookie(from: "name=value; Path=/test")
            #expect(cookie?.path == "/test")
        }

        @Test func testMaxAge() {
            let cookie = Cookie(from: "name=value; Max-Age=3600")
            #expect(cookie?.maxAge == 3600)
        }

        @Test func testSecure() {
            let cookie = Cookie(from: "name=value; Secure")
            #expect(cookie?.secure == true)
        }

        @Test func testHttpOnly() {
            let cookie = Cookie(from: "name=value; HttpOnly")
            #expect(cookie?.httpOnly == true)
        }

        @Test func testSameSite() {
            let cookie = Cookie(from: "name=value; SameSite=Strict")
            #expect(cookie?.sameSite == .strict)
        }

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
}
