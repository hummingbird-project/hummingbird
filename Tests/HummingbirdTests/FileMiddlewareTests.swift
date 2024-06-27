//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import XCTest

class FileMiddlewareTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    var rfc1123Formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    func testRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).jpg"
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), text)
                XCTAssertEqual(response.headers[.contentType], "image/jpeg")
            }
        }
    }

    func testNotAFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "missed.jpg", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testReadLargeFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 380_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                XCTAssertEqual(response.body, buffer)
            }
        }
    }

    func testReadRange() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 326_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=100-3999"]) { response in
                let slice = buffer.getSlice(at: 100, length: 3900)
                XCTAssertEqual(response.body, slice)
                XCTAssertEqual(response.headers[.contentRange], "bytes 100-3999/326000")
                XCTAssertEqual(response.headers[.contentLength], "3900")
                XCTAssertEqual(response.headers[.contentType], "text/plain")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=0-0"]) { response in
                let slice = buffer.getSlice(at: 0, length: 1)
                XCTAssertEqual(response.body, slice)
                XCTAssertEqual(response.headers[.contentRange], "bytes 0-0/326000")
                XCTAssertEqual(response.headers[.contentLength], "1")
                XCTAssertEqual(response.headers[.contentType], "text/plain")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=-3999"]) { response in
                let slice = buffer.getSlice(at: 0, length: 4000)
                XCTAssertEqual(response.body, slice)
                XCTAssertEqual(response.headers[.contentLength], "4000")
                XCTAssertEqual(response.headers[.contentRange], "bytes 0-3999/326000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=6000-"]) { response in
                let slice = buffer.getSlice(at: 6000, length: 320_000)
                XCTAssertEqual(response.body, slice)
                XCTAssertEqual(response.headers[.contentLength], "320000")
                XCTAssertEqual(response.headers[.contentRange], "bytes 6000-325999/326000")
            }
        }
    }

    func testIfRangeRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 10000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let (eTag, modificationDate) = try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=-3999"]) { response -> (String, String) in
                let eTag = try XCTUnwrap(response.headers[.eTag])
                let modificationDate = try XCTUnwrap(response.headers[.lastModified])
                let slice = buffer.getSlice(at: 0, length: 4000)
                XCTAssertEqual(response.body, slice)
                XCTAssertEqual(response.headers[.contentRange], "bytes 0-3999/10000")
                return (eTag, modificationDate)
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: eTag]) { response in
                XCTAssertEqual(response.headers[.contentRange], "bytes 4000-9999/10000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: modificationDate]) { response in
                XCTAssertEqual(response.headers[.contentRange], "bytes 4000-9999/10000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: "not valid"]) { response in
                XCTAssertNil(response.headers[.contentRange])
            }
        }
    }

    func testHead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let date = Date()
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testHead.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.execute(uri: "/testHead.txt", method: .head) { response in
                XCTAssertEqual(response.body.readableBytes, 0)
                XCTAssertEqual(response.headers[.contentLength], text.utf8.count.description)
                XCTAssertEqual(response.headers[.contentType], "text/plain")
                let responseDateString = try XCTUnwrap(response.headers[.lastModified])
                let responseDate = try XCTUnwrap(self.rfc1123Formatter.date(from: responseDateString))
                XCTAssert(date < responseDate + 2 && date > responseDate - 2)
            }
        }
    }

    func testETag() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            var eTag: String?
            try await client.execute(uri: filename, method: .head) { response in
                eTag = try XCTUnwrap(response.headers[.eTag])
            }
            try await client.execute(uri: filename, method: .head) { response in
                XCTAssertEqual(response.headers[.eTag], eTag)
            }
        }
    }

    func testIfNoneMatch() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let eTag = try await client.execute(uri: filename, method: .head) { response in
                return try XCTUnwrap(response.headers[.eTag])
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifNoneMatch: eTag]) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            var headers: HTTPFields = .init()
            headers[values: .ifNoneMatch] = ["test", "\(eTag)"]
            try await client.execute(uri: filename, method: .get, headers: headers) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifNoneMatch: "dummyETag"]) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testIfModifiedSince() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let modifiedDate = try await client.execute(uri: filename, method: .head) { response in
                return try XCTUnwrap(response.headers[.lastModified])
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifModifiedSince: modifiedDate]) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            // one minute before current date
            let date = try XCTUnwrap(self.rfc1123Formatter.string(from: Date(timeIntervalSinceNow: -60)))
            try await client.execute(uri: filename, method: .get, headers: [.ifModifiedSince: date]) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testCacheControl() async throws {
        let router = Router()
        let cacheControl: CacheControl = .init([
            (.text, [.maxAge(60 * 60 * 24 * 30)]),
            (.imageJpeg, [.maxAge(60 * 60 * 24 * 30), .private]),
        ])
        router.middlewares.add(FileMiddleware(".", cacheControl: cacheControl))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
        let fileURL2 = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL2))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL2)) }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                XCTAssertEqual(response.headers[.cacheControl], "max-age=2592000")
            }
            try await client.execute(uri: "/test.jpg", method: .get) { response in
                XCTAssertEqual(response.headers[.cacheControl], "max-age=2592000, private")
            }
        }
    }

    func testIndexHtml() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "index.html")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), text)
            }
        }
    }

    func testFolder() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: false))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
            }
        }
    }

    func testCustomFileProvider() async throws {
        // basic file provider
        struct MemoryFileProvider: FileProvider {
            struct FileAttributes: FileMiddlewareFileAttributes {
                var isFolder: Bool { false }
                var modificationDate: Date { .distantPast }
                let size: Int
            }

            init() {
                self.files = [:]
            }

            func getFileIdentifier(_ path: String) -> String? {
                return path
            }

            func getAttributes(id path: String) async throws -> FileAttributes? {
                guard let file = files[path] else { return nil }
                return .init(size: file.readableBytes)
            }

            func loadFile(id path: String, context: some RequestContext) async throws -> ResponseBody {
                guard let file = files[path] else { throw HTTPError(.notFound) }
                return .init(byteBuffer: file)
            }

            func loadFile(id path: String, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody {
                guard let file = files[path] else { throw HTTPError(.notFound) }
                guard let slice = file.getSlice(at: range.lowerBound, length: range.count) else { throw HTTPError(.rangeNotSatisfiable) }
                return .init(byteBuffer: slice)
            }

            var files: [String: ByteBuffer]
        }

        var fileProvider = MemoryFileProvider()
        fileProvider.files["test"] = ByteBuffer(string: "Test this")

        let router = Router()
        router.middlewares.add(FileMiddleware(fileProvider: fileProvider))
        let app = Application(router: router)
        try await app.test(.router) { client in
            try await client.execute(uri: "test", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(String(buffer: response.body), "Test this")
            }
        }
    }
}
