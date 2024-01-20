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
import Logging
import XCTest

class HummingBirdURLEncodedTests: XCTestCase {
    struct User: HBResponseCodable {
        let name: String
        let email: String
        let age: Int
    }

    struct URLEncodedCodingRequestContext: HBRequestContext {
        var coreContext: HBCoreRequestContext

        init(allocator: ByteBufferAllocator, logger: Logger) {
            self.coreContext = .init(
                allocator: allocator,
                logger: logger
            )
        }

        var requestDecoder: URLEncodedFormDecoder { .init() }
        var responseEncoder: URLEncodedFormEncoder { .init() }
    }

    struct Error: Swift.Error {}

    func testDecode() async throws {
        let router = HBRouter(context: URLEncodedCodingRequestContext.self)
        router.put("/user") { request, context -> HTTPResponse.Status in
            guard let user = try? await request.decode(as: User.self, context: context) else { throw HBHTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let body = "name=John%20Smith&email=john.smith%40email.com&age=25"
            try await client.XCTExecute(uri: "/user", method: .put, body: ByteBufferAllocator().buffer(string: body)) {
                XCTAssertEqual($0.status, .ok)
            }
        }
    }

    func testEncode() async throws {
        let router = HBRouter(context: URLEncodedCodingRequestContext.self)
        router.get("/user") { _, _ -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/user", method: .get) { response in
                let user = try URLEncodedFormDecoder().decode(User.self, from: String(buffer: response.body))
                XCTAssertEqual(user.name, "John Smith")
                XCTAssertEqual(user.email, "john.smith@email.com")
                XCTAssertEqual(user.age, 25)
            }
        }
    }
}
