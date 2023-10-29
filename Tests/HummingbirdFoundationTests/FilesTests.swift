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

class HummingbirdFilesTests: XCTestCase {
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
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test.jpg", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readString(length: body.readableBytes), text)
                XCTAssertEqual(response.headers["content-type"].first, "image/jpeg")
            }
        }
    }

    func testReadLargeFile() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 380_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test.txt", method: .GET) { response in
                let body = try XCTUnwrap(response.body)
                XCTAssertEqual(body, buffer)
            }
        }
    }

    func testReadRange() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 326_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=100-3999"]) { response in
                let body = try XCTUnwrap(response.body)
                let slice = buffer.getSlice(at: 100, length: 3900)
                XCTAssertEqual(body, slice)
                XCTAssertEqual(response.headers["content-range"].first, "bytes 100-3999/326000")
                XCTAssertEqual(response.headers["content-type"].first, "text/plain")
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=0-0"]) { response in
                let body = try XCTUnwrap(response.body)
                let slice = buffer.getSlice(at: 0, length: 1)
                XCTAssertEqual(body, slice)
                XCTAssertEqual(response.headers["content-range"].first, "bytes 0-0/326000")
                XCTAssertEqual(response.headers["content-type"].first, "text/plain")
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=-3999"]) { response in
                let body = try XCTUnwrap(response.body)
                let slice = buffer.getSlice(at: 0, length: 4000)
                XCTAssertEqual(body, slice)
                XCTAssertEqual(response.headers["content-length"].first, "4000")
                XCTAssertEqual(response.headers["content-range"].first, "bytes 0-3999/326000")
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=6000-"]) { response in
                let body = try XCTUnwrap(response.body)
                let slice = buffer.getSlice(at: 6000, length: 320_000)
                XCTAssertEqual(body, slice)
                XCTAssertEqual(response.headers["content-range"].first, "bytes 6000-325999/326000")
            }
        }
    }

    func testIfRangeRead() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 10000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let (eTag, modificationDate) = try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=-3999"]) { response -> (String, String) in
                let eTag = try XCTUnwrap(response.headers["eTag"].first)
                let modificationDate = try XCTUnwrap(response.headers["modified-date"].first)
                let body = try XCTUnwrap(response.body)
                let slice = buffer.getSlice(at: 0, length: 4000)
                XCTAssertEqual(body, slice)
                XCTAssertEqual(response.headers["content-range"].first, "bytes 0-3999/10000")
                return (eTag, modificationDate)
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=4000-", "if-range": eTag]) { response in
                XCTAssertEqual(response.headers["content-range"].first, "bytes 4000-9999/10000")
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=4000-", "if-range": modificationDate]) { response in
                XCTAssertEqual(response.headers["content-range"].first, "bytes 4000-9999/10000")
            }

            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=4000-", "if-range": "not valid"]) { response in
                XCTAssertNil(response.headers["content-range"].first)
            }
        }
    }

    func testHead() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let date = Date()
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testHead.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/testHead.txt", method: .HEAD) { response in
                XCTAssertNil(response.body)
                XCTAssertEqual(response.headers["Content-Length"].first, text.utf8.count.description)
                XCTAssertEqual(response.headers["content-type"].first, "text/plain")
                let responseDateString = try XCTUnwrap(response.headers["modified-date"].first)
                let responseDate = try XCTUnwrap(self.rfc1123Formatter.date(from: responseDateString))
                XCTAssert(date < responseDate + 2 && date > responseDate - 2)
            }
        }
    }

    func testETag() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            var eTag: String?
            try await client.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
                eTag = try XCTUnwrap(response.headers["eTag"].first)
            }
            try await client.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
                XCTAssertEqual(response.headers["eTag"].first, eTag)
            }
        }
    }

    func testIfNoneMatch() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let eTag = try await client.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
                return try XCTUnwrap(response.headers["eTag"].first)
            }
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["if-none-match": eTag]) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            var headers: HTTPHeaders = ["if-none-match": "test"]
            headers.add(name: "if-none-match", value: "\(eTag)")
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: headers) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["if-none-match": "dummyETag"]) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testIfModifiedSince() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware("."))
        let app = HBApplication(responder: router.buildResponder())

        let buffer = self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            let modifiedDate = try await client.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
                return try XCTUnwrap(response.headers["modified-date"].first)
            }
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["if-modified-since": modifiedDate]) { response in
                XCTAssertEqual(response.status, .notModified)
            }
            // one minute before current date
            let date = try XCTUnwrap(self.rfc1123Formatter.string(from: Date(timeIntervalSinceNow: -60)))
            try await client.XCTExecute(uri: "/test.txt", method: .GET, headers: ["if-modified-since": date]) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }

    func testCacheControl() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        let cacheControl: HBCacheControl = .init([
            (.text, [.maxAge(60 * 60 * 24 * 30)]),
            (.imageJpeg, [.maxAge(60 * 60 * 24 * 30), .private]),
        ])
        router.middlewares.add(HBFileMiddleware(".", cacheControl: cacheControl))
        let app = HBApplication(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
        let fileURL2 = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL2))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL2)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/test.txt", method: .GET) { response in
                XCTAssertEqual(response.headers["cache-control"].first, "max-age=2592000")
            }
            try await client.XCTExecute(uri: "/test.jpg", method: .GET) { response in
                XCTAssertEqual(response.headers["cache-control"].first, "max-age=2592000, private")
            }
        }
    }

    func testIndexHtml() async throws {
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.middlewares.add(HBFileMiddleware(".", searchForIndexHtml: true))
        let app = HBApplication(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "index.html")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        try await app.test(.router) { client in
            try await client.XCTExecute(uri: "/", method: .GET) { response in
                var body = try XCTUnwrap(response.body)
                XCTAssertEqual(body.readString(length: body.readableBytes), text)
            }
        }
    }

    func testWrite() async throws {
        let filename = "testWrite.txt"
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.put("store") { request, context -> HTTPResponseStatus in
            let fileIO = HBFileIO(threadPool: context.applicationContext.threadPool)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context, logger: context.logger)
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = ByteBufferAllocator().buffer(string: "This is a test")
            try await client.XCTExecute(uri: "/store", method: .PUT, body: buffer) { response in
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
        let router = HBRouterBuilder(context: HBTestRouterContext.self)
        router.put("store") { request, context -> HTTPResponseStatus in
            let fileIO = HBFileIO(threadPool: context.applicationContext.threadPool)
            try await fileIO.writeFile(contents: request.body, path: filename, context: context, logger: context.logger).get()
            return .ok
        }
        let app = HBApplication(responder: router.buildResponder())

        try await app.test(.router) { client in
            let buffer = self.randomBuffer(size: 400_000)
            try await client.XCTExecute(uri: "/store", method: .PUT, body: buffer) { response in
                XCTAssertEqual(response.status, .ok)
            }

            let fileURL = URL(fileURLWithPath: filename)
            let data = try Data(contentsOf: fileURL)
            defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
            XCTAssertEqual(Data(buffer: buffer), data)
        }
    }
}
