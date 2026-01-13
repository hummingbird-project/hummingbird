//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import NIOPosix
import Testing

struct FileMiddlewareTests {
    static func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    static var rfc9110Formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyy HH:mm:ss z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    @Test func testRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).jpg"
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                #expect(String(buffer: response.body) == text)
                #expect(response.headers[.contentType] == "image/jpeg")
            }
        }
    }

    @Test func testNotAFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "missed.jpg", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test func testReadLargeFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 380_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                #expect(response.body == buffer)
            }
        }
    }

    @Test func testReadRange() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 326_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=100-3999"]) { response in
                let slice = buffer.getSlice(at: 100, length: 3900)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 100-3999/326000")
                #expect(response.headers[.contentLength] == "3900")
                #expect(response.headers[.contentType] == "text/plain")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=0-0"]) { response in
                let slice = buffer.getSlice(at: 0, length: 1)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 0-0/326000")
                #expect(response.headers[.contentLength] == "1")
                #expect(response.headers[.contentType] == "text/plain")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=-3999"]) { response in
                let slice = buffer.getSlice(at: 0, length: 4000)
                #expect(response.body == slice)
                #expect(response.headers[.contentLength] == "4000")
                #expect(response.headers[.contentRange] == "bytes 0-3999/326000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=6000-"]) { response in
                let slice = buffer.getSlice(at: 6000, length: 320_000)
                #expect(response.body == slice)
                #expect(response.headers[.contentLength] == "320000")
                #expect(response.headers[.contentRange] == "bytes 6000-325999/326000")
            }
        }
    }

    @Test func testIfRangeRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 10000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            let (eTag, modificationDate) = try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=-3999"]) {
                response -> (String, String) in
                let eTag = try #require(response.headers[.eTag])
                let modificationDate = try #require(response.headers[.lastModified])
                let slice = buffer.getSlice(at: 0, length: 4000)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 0-3999/10000")
                return (eTag, modificationDate)
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: eTag]) { response in
                #expect(response.headers[.contentRange] == "bytes 4000-9999/10000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: modificationDate]) { response in
                #expect(response.headers[.contentRange] == "bytes 4000-9999/10000")
            }

            try await client.execute(uri: filename, method: .get, headers: [.range: "bytes=4000-", .ifRange: "not valid"]) { response in
                #expect(response.headers[.contentRange] == nil)
            }
        }
    }

    @Test func testHead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let date = Date()
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testHead.txt")
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: "/testHead.txt", method: .head) { response in
                #expect(response.body.readableBytes == 0)
                #expect(response.headers[.contentLength] == text.utf8.count.description)
                #expect(response.headers[.contentType] == "text/plain")
                let responseDateString = try #require(response.headers[.lastModified])
                let responseDate = try #require(Self.rfc9110Formatter.date(from: responseDateString))
                #expect(date < responseDate + 2 && date > responseDate - 2)
            }
        }
    }

    @Test func testETag() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            var eTag: String?
            try await client.execute(uri: filename, method: .head) { response in
                eTag = response.headers[.eTag]
            }
            try await client.execute(uri: filename, method: .head) { response in
                #expect(response.headers[.eTag] == eTag)
            }
        }
    }

    @Test func testIfNoneMatch() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            let eTag = try await client.execute(uri: filename, method: .head) { response in
                try #require(response.headers[.eTag])
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifNoneMatch: eTag]) { response in
                #expect(response.status == .notModified)
            }
            var headers: HTTPFields = .init()
            headers[values: .ifNoneMatch] = ["test", "\(eTag)"]
            try await client.execute(uri: filename, method: .get, headers: headers) { response in
                #expect(response.status == .notModified)
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifNoneMatch: "dummyETag"]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testIfModifiedSince() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).txt"
        let buffer = Self.randomBuffer(size: 16200)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            let modifiedDate = try await client.execute(uri: filename, method: .head) { response in
                try #require(response.headers[.lastModified])
            }
            try await client.execute(uri: filename, method: .get, headers: [.ifModifiedSince: modifiedDate]) { response in
                #expect(response.status == .notModified)
            }
            // one minute before current date
            let date = Self.rfc9110Formatter.string(from: Date(timeIntervalSinceNow: -60))
            try await client.execute(uri: filename, method: .get, headers: [.ifModifiedSince: date]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test func testCacheControl() async throws {
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
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }
        let fileURL2 = URL(fileURLWithPath: "test.jpg")
        #expect(throws: Never.self) { try data.write(to: fileURL2) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL2) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                #expect(response.headers[.cacheControl] == "max-age=2592000")
            }
            try await client.execute(uri: "/test.jpg", method: .get) { response in
                #expect(response.headers[.cacheControl] == "max-age=2592000, private")
            }
        }
    }

    @Test func testIndexHtml() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "index.html")
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(String(buffer: response.body) == text)
            }
        }
    }

    @Test func testFolderRedirect() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        try FileManager.default.createDirectory(atPath: "testFolderRedirect", withIntermediateDirectories: false)
        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testFolderRedirect/index.html")
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer {
            #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) }
            #expect(throws: Never.self) { try FileManager.default.removeItem(atPath: "testFolderRedirect") }
        }

        try await app.test(.router) { client in
            try await client.execute(uri: "/testFolderRedirect", method: .get) { response in
                #expect(response.status == .movedPermanently)
                #expect(response.headers[.location] == "/testFolderRedirect/")
            }
        }
    }

    @Test func testSymlink() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testSymlink.html")
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        let fileIO = NonBlockingFileIO(threadPool: .singleton)

        try await app.test(.router) { client in
            try await client.execute(uri: "/testSymlink.html", method: .get) { response in
                #expect(String(buffer: response.body) == text)
            }

            try await client.execute(uri: "/testSymlink2.html", method: .get) { response in
                #expect(String(buffer: response.body) == "")
            }

            try await fileIO.symlink(path: "testSymlink2.html", to: "testSymlink.html")

            do {
                try await client.execute(uri: "/testSymlink2.html", method: .get) { response in
                    #expect(String(buffer: response.body) == text)
                }

                try await fileIO.unlink(path: "testSymlink2.html")
            } catch {
                try await fileIO.unlink(path: "testSymlink2.html")
                throw error
            }
        }
    }

    @Test func testOnThrowCustom404() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: true))
        struct Custom404Error: HTTPResponseError {
            var status: HTTPResponse.Status { .notFound }

            func response(from request: Request, context: some RequestContext) throws -> Response {
                Response(status: self.status)
            }
        }
        router.get { _, _ -> String in
            throw Custom404Error()
        }
        let app = Application(responder: router.buildResponder())

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "testOnThrowCustom404.html")
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: "/testOnThrowCustom404.html", method: .get) { response in
                #expect(String(buffer: response.body) == text)
            }
        }
    }

    @Test func testFolder() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(".", searchForIndexHtml: false))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test func testPathPrefix() async throws {
        // echo file provider. Returns file name as contents of file
        struct MemoryFileProvider: FileProvider {
            let prefix: String
            struct FileAttributes: FileMiddlewareFileAttributes {
                var isFolder: Bool
                var modificationDate: Date { .distantPast }
                let size: Int
            }

            func getFileIdentifier(_ path: String) -> String? {
                path
            }

            func getAttributes(id path: String) async throws -> FileAttributes? {
                .init(
                    isFolder: path.last == "/",
                    size: path.utf8.count
                )
            }

            func loadFile(id path: String, context: some RequestContext) async throws -> ResponseBody {
                let buffer = ByteBuffer(string: self.prefix + path)
                return .init(byteBuffer: buffer)
            }

            func loadFile(id path: String, range: ClosedRange<Int>, context: some RequestContext) async throws -> ResponseBody {
                let buffer = ByteBuffer(string: self.prefix + path)
                guard let slice = buffer.getSlice(at: range.lowerBound, length: range.count) else { throw HTTPError(.rangeNotSatisfiable) }
                return .init(byteBuffer: slice)
            }
        }
        let router = Router()
        router.add(middleware: FileMiddleware(fileProvider: MemoryFileProvider(prefix: "memory:/"), urlBasePath: "/test", searchForIndexHtml: true))
        router.add(middleware: FileMiddleware(fileProvider: MemoryFileProvider(prefix: "memory2:/"), urlBasePath: "/test2", searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "memory://hello")
            }
            try await client.execute(uri: "/test/hello/", method: .get) { response in
                #expect(String(buffer: response.body) == "memory://hello/index.html")
            }
            try await client.execute(uri: "/test", method: .get) { response in
                #expect(String(buffer: response.body) == "memory://index.html")
            }
            try await client.execute(uri: "/test/", method: .get) { response in
                #expect(String(buffer: response.body) == "memory://index.html")
            }
            try await client.execute(uri: "/goodbye", method: .get) { response in
                #expect(response.status == .notFound)
            }
            try await client.execute(uri: "/testHello", method: .get) { response in
                #expect(response.status == .notFound)
            }
            try await client.execute(uri: "/test2/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "memory2://hello")
            }
            try await client.execute(uri: "/test2/hello/", method: .get) { response in
                #expect(String(buffer: response.body) == "memory2://hello/index.html")
            }
            try await client.execute(uri: "/test2", method: .get) { response in
                #expect(String(buffer: response.body) == "memory2://index.html")
            }
        }
    }

    @Test func testCustomFileProvider() async throws {
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
                path
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
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Test this")
            }
        }
    }

    @Test(arguments: ["1.jpg", "2.JPG", "3.JpG", "4.JPeG", "5.JPEG"])
    func testFilesWithNonLowercaseFileExtensions(fileSuffix: String) async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware("."))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let fileURL = URL(fileURLWithPath: "\(#function)\(fileSuffix)")
            let filename = fileURL.lastPathComponent
            let data = Data()
            #expect(throws: Never.self) { try data.write(to: fileURL) }
            defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

            try await client.execute(uri: filename, method: .get) { response in
                #expect(response.headers[.contentType] == "image/jpeg")
            }
        }
    }

    @Test func testCustomMIMEType() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        router.middlewares.add(FileMiddleware(".").withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8"))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).m3u8"
        let content = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-ALLOW-CACHE:YES
            #EXT-X-TARGETDURATION:0
            #EXT-X-MEDIA-SEQUENCE:10
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXT-X-MAP:URI="init.mp4"
            #EXT-X-DISCONTINUITY
            #EXTINF:0.000000,
            live000010.m4s
            """
        let data = Data(content.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                #expect(String(buffer: response.body) == content)
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/x-mpegurl"])
                #expect(validTypes.contains(contentType))
            }
        }
    }

    @Test func testCustomMIMETypeCaseInsensitivity() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        router.middlewares.add(FileMiddleware(".").withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8"))
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).m3U8"
        let data = Data("".utf8)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/x-mpegurl"])
                #expect(validTypes.contains(contentType))
            }
        }
    }

    @Test func testCustomMIMETypes() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        let fileMiddleware = FileMiddleware<BasicRequestContext, LocalFileSystem>(".")
            .withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8")
            .withAdditionalMediaTypes(forFileExtensions: [
                "foo": MediaType(type: .any, subType: "x-foo"),
                "M3U8": MediaType(type: .application, subType: "vnd.apple.mpegURL"),
            ])
        router.middlewares.add(fileMiddleware)
        let app = Application(responder: router.buildResponder())

        let filename = "\(#function).m3u8"
        let content = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-ALLOW-CACHE:YES
            #EXT-X-TARGETDURATION:0
            #EXT-X-MEDIA-SEQUENCE:10
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXT-X-MAP:URI="init.mp4"
            #EXT-X-DISCONTINUITY
            #EXTINF:0.000000,
            live000010.m4s
            """
        let data = Data(content.utf8)
        let fileURL = URL(fileURLWithPath: filename)
        #expect(throws: Never.self) { try data.write(to: fileURL) }
        defer { #expect(throws: Never.self) { try FileManager.default.removeItem(at: fileURL) } }

        try await app.test(.router) { client in
            try await client.execute(uri: filename, method: .get) { response in
                #expect(String(buffer: response.body) == content)
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/vnd.apple.mpegURL"])
                #expect(validTypes.contains(contentType))
            }
        }
    }
}
