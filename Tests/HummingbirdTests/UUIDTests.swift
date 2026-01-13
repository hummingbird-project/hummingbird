//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Hummingbird
import Logging
import Testing

@Suite("Test UUID as URL/query parameters")
struct UUIDTests {
    @Test func testGetUUID() async throws {
        let router = Router()
        router.get(":id") { _, context -> UUID? in
            context.parameters.get("id", as: UUID.self)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            try await client.execute(uri: "\(uuid)", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "\"\(uuid.uuidString)\"")
            }
        }
    }

    @Test func testRequireUUID() async throws {
        let router = Router()
        router.get(":id") { _, context -> UUID in
            try context.parameters.require("id", as: UUID.self)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            try await client.execute(uri: "\(uuid)", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "\"\(uuid.uuidString)\"")
            }
        }
    }

    @Test func testGetUUIDs() async throws {
        let router = Router()
        router.get { request, _ -> [UUID] in
            let queryParameters = request.uri.queryParameters
            return queryParameters.getAll("id", as: UUID.self)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            let uuid2 = UUID()
            try await client.execute(uri: "/?id=\(uuid)&id=\(uuid2)&id=Wrong", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "[\"\(uuid.uuidString)\",\"\(uuid2.uuidString)\"]")
            }
        }
    }

    @Test func testRequireUUIDs() async throws {
        let router = Router()
        router.get { request, _ -> [UUID] in
            let queryParameters = request.uri.queryParameters
            return try queryParameters.requireAll("id", as: UUID.self)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            let uuid2 = UUID()
            // test good request
            try await client.execute(uri: "/?id=\(uuid)&id=\(uuid2)", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "[\"\(uuid.uuidString)\",\"\(uuid2.uuidString)\"]")
            }
            // test bad request
            try await client.execute(uri: "/?id=\(uuid)&id=\(uuid2)&id=Wrong", method: .get) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
}
