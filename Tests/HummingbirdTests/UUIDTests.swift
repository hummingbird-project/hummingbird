//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import Logging
import XCTest

final class UUIDTests: XCTestCase {
    func testGetUUID() async throws {
        let router = HBRouter()
        router.get(":id") { _, context -> UUID? in
            return context.parameters.get("id", as: UUID.self)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            try await client.XCTExecute(uri: "\(uuid)", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: body), "\"\(uuid.uuidString)\"")
            }
        }
    }

    func testRequireUUID() async throws {
        let router = HBRouter()
        router.get(":id") { _, context -> UUID in
            return try context.parameters.require("id", as: UUID.self)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            try await client.XCTExecute(uri: "\(uuid)", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: body), "\"\(uuid.uuidString)\"")
            }
        }
    }

    func testGetUUIDs() async throws {
        let router = HBRouter()
        router.get { request, _ -> [UUID] in
            let queryParameters = request.uri.queryParameters
            return queryParameters.getAll("id", as: UUID.self)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            let uuid2 = UUID()
            try await client.XCTExecute(uri: "/?id=\(uuid)&id=\(uuid2)&id=Wrong", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: body), "[\"\(uuid.uuidString)\",\"\(uuid2.uuidString)\"]")
            }
        }
    }

    func testRequireUUIDs() async throws {
        let router = HBRouter()
        router.get { request, _ -> [UUID] in
            let queryParameters = request.uri.queryParameters
            return try queryParameters.requireAll("id", as: UUID.self)
        }
        let app = HBApplication(responder: router.buildResponder())
        try await app.test(.router) { client in
            let uuid = UUID()
            let uuid2 = UUID()
            // test good request
            try await client.XCTExecute(uri: "/?id=\(uuid)&id=\(uuid2)", method: .get) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: body), "[\"\(uuid.uuidString)\",\"\(uuid2.uuidString)\"]")
            }
            // test bad request
            try await client.XCTExecute(uri: "/?id=\(uuid)&id=\(uuid2)&id=Wrong", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }
}
