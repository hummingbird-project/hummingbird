//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
import XCTest

class FileIOTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testReadFileIO() async throws {
        let router = HBRouter(context: HBTestRouterContext.self)
        router.get("test.jpg") { _, context -> HBResponse in
            let fileIO = HBFileIO(threadPool: context.threadPool)
            let body = try await fileIO.loadFile(path: "test.jpg", context: context, logger: context.logger)
            return .init(status: .ok, headers: [:], body: body)
        }
        let buffer = self.randomBuffer(size: 320_003)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test.jpg", method: .get) { response in
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    func testWrite() async throws {
        let filename = "testWrite.txt"
        let router = HBRouter(context: HBTestRouterContext.self)
        router.put("store") { request, context -> HTTPResponse.Status in
            let fileIO = HBFileIO(threadPool: context.threadPool)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context, logger: context.logger)
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = ByteBufferAllocator().buffer(string: "This is a test")
            try await client.XCTExecute(uri: "/store", method: .put, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        let fileURL = URL(fileURLWithPath: filename)
        let data = try Data(contentsOf: fileURL)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
        XCTAssertEqual(String(decoding: data, as: Unicode.UTF8.self), "This is a test")
    }

    func testWriteLargeFile() async throws {
        let filename = "testWriteLargeFile.txt"
        let router = HBRouter(context: HBTestRouterContext.self)
        router.put("store") { request, context -> HTTPResponse.Status in
            let fileIO = HBFileIO(threadPool: context.threadPool)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context, logger: context.logger)
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = self.randomBuffer(size: 400_000)
            try await client.XCTExecute(uri: "/store", method: .put, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }

            let fileURL = URL(fileURLWithPath: filename)
            let data = try Data(contentsOf: fileURL)
            defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
            XCTAssertEqual(Data(buffer: buffer), data)
        }
    }
}
