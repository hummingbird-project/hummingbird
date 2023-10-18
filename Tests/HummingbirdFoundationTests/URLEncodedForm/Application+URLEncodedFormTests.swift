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
import HummingbirdFoundation
import HummingbirdXCT
import XCTest

class HummingBirdURLEncodedTests: XCTestCase {
    struct User: HBResponseCodable {
        let name: String
        let email: String
        let age: Int
    }

    struct Error: Swift.Error {}

    func testDecode() async throws {
        let app = HBApplicationBuilder(requestContext: HBTestRouterContext.self)
        app.decoder = URLEncodedFormDecoder()
        app.router.put("/user") { request, context -> HTTPResponseStatus in
            guard let user = try? request.decode(as: User.self, using: context) else { throw HBHTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        try await app.buildAndTest(.router) { client in
            let body = "name=John%20Smith&email=john.smith%40email.com&age=25"
            try await client.XCTExecute(uri: "/user", method: .PUT, body: ByteBufferAllocator().buffer(string: body)) {
                XCTAssertEqual($0.status, .ok)
            }
        }
    }

    func testEncode() async throws {
        let app = HBApplicationBuilder(requestContext: HBTestRouterContext.self)
        app.encoder = URLEncodedFormEncoder()
        app.router.get("/user") { _, _ -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/user", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                let bodyString = try XCTUnwrap(body.readString(length: body.readableBytes))
                let user = try URLEncodedFormDecoder().decode(User.self, from: bodyString)
                XCTAssertEqual(user.name, "John Smith")
                XCTAssertEqual(user.email, "john.smith@email.com")
                XCTAssertEqual(user.age, 25)
            }
        }
    }
}
