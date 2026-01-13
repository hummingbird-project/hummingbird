//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import Testing

struct URLEncodedFormTests {
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

    @Test func testDecode() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.put("/user") { request, context -> HTTPResponse.Status in
            guard let user = try? await request.decode(as: User.self, context: context) else { throw HTTPError(.badRequest) }
            #expect(user.name == "John Smith")
            #expect(user.email == "john.smith@email.com")
            #expect(user.age == 25)
            return .ok
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let body = "name=John%20Smith&email=john.smith%40email.com&age=25"
            try await client.execute(uri: "/user", method: .put, body: ByteBufferAllocator().buffer(string: body)) {
                #expect($0.status == .ok)
            }
        }
    }

    @Test func testEncode() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.get("/user") { _, _ -> User in
            User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user", method: .get) { response in
                let user = try URLEncodedFormDecoder().decode(User.self, from: String(buffer: response.body))
                #expect(user.name == "John Smith")
                #expect(user.email == "john.smith@email.com")
                #expect(user.age == 25)
            }
        }
    }

    @Test func testDecodeQuery() async throws {
        let router = Router()
        router.post("/user") { request, context -> User in
            let user = try request.uri.decodeQuery(as: User.self, context: context)
            return user
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/user?name=John%20Smith&email=john.smith@email.com&age=25", method: .post) { response in
                let user = try JSONDecoder().decode(User.self, from: Data(buffer: response.body))
                #expect(user.name == "John Smith")
                #expect(user.email == "john.smith@email.com")
                #expect(user.age == 25)
            }
        }
    }

    @Test func testError() async throws {
        let router = Router(context: URLEncodedCodingRequestContext.self)
        router.get("/error") { _, _ -> User in
            throw HTTPError(.badRequest, message: "Bad Request")
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/error", method: .get) { response in
                #expect(response.status == .badRequest)
                #expect(response.headers[.contentType] == "application/x-www-form-urlencoded")
                #expect(String(buffer: response.body) == "error[message]=Bad%20Request")
            }
        }
    }
}
