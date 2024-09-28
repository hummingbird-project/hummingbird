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
import HummingbirdTesting
import Logging
import NIOCore
import XCTest

final class HummingBirdURLEncodedTests: XCTestCase {
    struct User: ResponseCodable {
        let name: String
        let email: String
        let age: Int
    }

    struct URLEncodedCodingRequestContext: RequestContext {
        var coreContext: CoreRequestContextStorage

        init(source: Source) {
            self.coreContext = .init(source: source)
        }

        var requestDecoder: URLEncodedFormDecoder { .init() }
        var responseEncoder: URLEncodedFormEncoder { .init() }
    }

    struct Error: Swift.Error {}

    func testDecode() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.put("/user") { request, context -> HTTPResponse.Status in
            guard let user = try? await request.decode(as: User.self, context: context) else { throw HTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let body = "name=John%20Smith&email=john.smith%40email.com&age=25"
            try await client.execute(uri: "/user", method: .put, body: ByteBufferAllocator().buffer(string: body)) {
                XCTAssertEqual($0.status, .ok)
            }
        }
    }

    func testEncode() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.get("/user") { _, _ -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user", method: .get) { response in
                let user = try URLEncodedFormDecoder().decode(User.self, from: String(buffer: response.body))
                XCTAssertEqual(user.name, "John Smith")
                XCTAssertEqual(user.email, "john.smith@email.com")
                XCTAssertEqual(user.age, 25)
            }
        }
    }

    func testError() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.get("/error") { _, _ -> User in
            throw HTTPError(.badRequest, message: "Bad Request")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/error", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
                XCTAssertEqual(response.headers[.contentType], "application/x-www-form-urlencoded")
                XCTAssertEqual(String(buffer: response.body), "error[message]=Bad%20Request")
            }
        }
    }
}
