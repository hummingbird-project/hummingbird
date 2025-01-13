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
import XCTest

final class JSONCodingTests: XCTestCase {
    struct User: ResponseCodable {
        let name: String
        let email: String
        let age: Int
    }

    struct Error: Swift.Error {}

    func testDecode() async throws {
        let router = Router()
        router.put("/user") { request, context -> HTTPResponse.Status in
            guard let user = try? await request.decode(as: User.self, context: context) else { throw HTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let body = #"{"name": "John Smith", "email": "john.smith@email.com", "age": 25}"#
            try await client.execute(uri: "/user", method: .put, body: ByteBufferAllocator().buffer(string: body)) {
                XCTAssertEqual($0.status, .ok)
            }
        }
    }

    func testEncode() async throws {
        let router = Router()
        router.get("/user") { _, _ -> User in
            User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user", method: .get) { response in
                let user = try JSONDecoder().decodeByteBuffer(User.self, from: response.body)
                XCTAssertEqual(user.name, "John Smith")
                XCTAssertEqual(user.email, "john.smith@email.com")
                XCTAssertEqual(user.age, 25)
            }
        }
    }

    func testEncode2() async throws {
        let router = Router()
        router.get("/json") { _, _ in
            ["message": "Hello, world!"]
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/json", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), #"{"message":"Hello, world!"}"#)
            }
        }
    }
}
