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
import Hummingbird
import HummingbirdFoundation
import HummingbirdXCT
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class HummingbirdAsyncFilesTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testRead() async throws {
        let app = HBApplicationBuilder()
        app.router.get("test.jpg") { request, context -> HBResponse in
            let fileIO = HBFileIO(threadPool: request.applicationContext.threadPool)
            let body = try await fileIO.loadFile(path: "test.jpg", context: request.context, logger: request.logger)
            return .init(status: .ok, headers: [:], body: body)
        }
        let buffer = self.randomBuffer(size: 320_003)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.buildAndTest(.router) { client in
            try await client.XCTExecute(uri: "/test.jpg", method: .GET) { response in
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    func testWrite() async throws {
        let filename = "testWrite.txt"
        let app = HBApplicationBuilder()
        app.router.put("store") { request, context -> HTTPResponseStatus in
            let fileIO = HBFileIO(threadPool: request.applicationContext.threadPool)
            try await fileIO.writeFile(
                contents: request.body,
                path: filename,
                context: request.context,
                logger: request.logger
            )
            return .ok
        }

        try await app.buildAndTest(.router) { client in
            let buffer = ByteBufferAllocator().buffer(string: "This is a test")
            try await client.XCTExecute(uri: "/store", method: .PUT, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }

            let fileURL = URL(fileURLWithPath: filename)
            let data = try Data(contentsOf: fileURL)
            defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
            XCTAssertEqual(String(decoding: data, as: Unicode.UTF8.self), "This is a test")
        }
    }
}
