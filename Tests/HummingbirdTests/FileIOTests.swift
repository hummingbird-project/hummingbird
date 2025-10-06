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
import HummingbirdTesting
import XCTest
import NIOFileSystem

final class FileIOTests: XCTestCase {
    static func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    static func withFile<Buffer: Sequence & Sendable, ReturnValue>(
        _ path: String,
        contents: Buffer,
        process: () async throws -> ReturnValue
    ) async throws -> ReturnValue where Buffer.Element == UInt8 {
        let fileSystem = FileSystem(threadPool: .singleton)
        try await fileSystem.withFileHandle(forWritingAt: .init(path)) { write in
            _ = try await write.write(contentsOf: contents, toAbsoluteOffset: 0)
        }
        do {
            let value = try await process()
            _ = try? await fileSystem.removeItem(at: .init(path))
            return value
        } catch {
            _ = try? await fileSystem.removeItem(at: .init(path))
            throw error
        }
    }

    func testReadFileIO() async throws {
        let router = Router()
        router.get("test.jpg") { _, context -> Response in
            let fileIO = FileIO(threadPool: .singleton)
            let body = try await fileIO.loadFile(path: "testReadFileIO.jpg", context: context)
            return .init(status: .ok, headers: [:], body: body)
        }
        let app = Application(responder: router.buildResponder())

        let buffer = Self.randomBuffer(size: 320_003)

        try await FileIOTests.withFile("testReadFileIO.jpg", contents: buffer.readableBytesView) {
            try await app.test(.router) { client in
                try await client.execute(uri: "/test.jpg", method: .get) { response in
                    XCTAssertEqual(response.body, buffer)
                }
            }
        }
    }

    func testReadMultipleFilesOnSameConnection() async throws {
        let router = Router()
        router.get("test.jpg") { _, context -> Response in
            let fileIO = FileIO(threadPool: .singleton)
            let body = try await fileIO.loadFile(path: "testReadMultipleFilesOnSameConnection.jpg", context: context)
            return .init(status: .ok, headers: [:], body: body)
        }
        let buffer = Self.randomBuffer(size: 54003)

        let app = Application(responder: router.buildResponder())

        try await FileIOTests.withFile("testReadMultipleFilesOnSameConnection.jpg", contents: buffer.readableBytesView) {
            try await app.test(.live) { client in
                try await client.execute(uri: "/test.jpg", method: .get) { response in
                    XCTAssertEqual(response.body, buffer)
                }
                try await client.execute(uri: "/test.jpg", method: .get) { response in
                    XCTAssertEqual(response.body, buffer)
                }
            }
        }
    }

    func testWrite() async throws {
        let filename = "testWrite.txt"
        let router = Router()
        router.put("store") { request, context -> HTTPResponse.Status in
            let fileIO = FileIO(threadPool: .singleton)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context)
            return .ok
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = ByteBufferAllocator().buffer(string: "This is a test")
            try await client.execute(uri: "/store", method: .put, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }

        let contents = try await FileSystem.shared.withFileHandle(forReadingAt: .init(filename)) { read in
            try await read.readToEnd(fromAbsoluteOffset: 0, maximumSizeAllowed: .unlimited)
        }
        try await FileSystem.shared.removeItem(at: .init(filename))
        XCTAssertEqual(String(buffer: contents), "This is a test")
    }

    func testWriteLargeFile() async throws {
        let filename = "testWriteLargeFile.txt"
        let router = Router()
        router.put("store") { request, context -> HTTPResponse.Status in
            let fileIO = FileIO(threadPool: .singleton)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context)
            return .ok
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.live) { client in
            let buffer = Self.randomBuffer(size: 400_000)
            try await client.execute(uri: "/store", method: .put, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }

            let contents = try await FileSystem.shared.withFileHandle(forReadingAt: .init(filename)) { read in
                try await read.readToEnd(fromAbsoluteOffset: 0, maximumSizeAllowed: .unlimited)
            }
            try await FileSystem.shared.removeItem(at: .init(filename))
            XCTAssertEqual(contents, buffer)
        }
    }

    func testReadEmptyFile() async throws {
        let router = Router()
        router.get("empty.txt") { _, context -> Response in
            let fileIO = FileIO(threadPool: .singleton)
            let body = try await fileIO.loadFile(path: "empty.txt", context: context)
            return .init(status: .ok, headers: [:], body: body)
        }
        let app = Application(responder: router.buildResponder())

        let buffer = ByteBuffer()

        try await FileIOTests.withFile("empty.txt", contents: buffer.readableBytesView) {
            try await app.test(.router) { client in
                try await client.execute(uri: "/empty.txt", method: .get) { response in
                    XCTAssertEqual(response.status, .ok)
                }
            }
        }
    }

    func testReadEmptyFilePart() async throws {
        let router = Router()
        router.get("empty.txt") { _, context -> Response in
            let fileIO = FileIO(threadPool: .singleton)
            let body = try await fileIO.loadFile(path: "empty.txt", range: 0...10, context: context)
            return .init(status: .ok, headers: [:], body: body)
        }

        let app = Application(responder: router.buildResponder())

        let buffer = ByteBuffer()

        try await FileIOTests.withFile("empty.txt", contents: buffer.readableBytesView) {
            try await app.test(.router) { client in
                try await client.execute(uri: "/empty.txt", method: .get) { response in
                    XCTAssertEqual(response.status, .ok)
                }
            }
        }
    }
}
