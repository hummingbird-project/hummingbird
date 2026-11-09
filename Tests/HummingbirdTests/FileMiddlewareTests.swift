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
import Logging
import NIOFoundationEssentialsCompat
import NIOPosix
import SystemPackage
import Testing
import _NIOFileSystem

@Suite(.tempFolder("public/FileMiddlewareTests"))
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

    func withFile<Buffer: Sequence & Sendable, ReturnValue>(
        _ path: FilePath,
        contents: Buffer,
        process: () async throws -> ReturnValue
    ) async throws -> ReturnValue where Buffer.Element == UInt8 {
        let fileSystem = FileSystem.shared
        try await fileSystem.withFileHandle(forWritingAt: path) { write in
            _ = try await write.write(contentsOf: contents, toAbsoluteOffset: 0)
        }
        do {
            let value = try await process()
            _ = try? await fileSystem.removeItem(at: path)
            return value
        } catch {
            _ = try? await fileSystem.removeItem(at: path)
            throw error
        }
    }

    @Test(.tempFile("testRead.jpg"))
    func testRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
                #expect(response.headers[.contentType] == "image/jpeg")
            }
        }
    }

    @Test(.tempFile("../testReadOutsidePublicFolder.jpg"))
    func testReadOutsidePublicFolder() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test func testNotAFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "missed.jpg", method: .get) { response in
                #expect(response.status == .notFound)
            }
        }
    }

    @Test(.tempFile(contentSize: 380_000))
    func testReadLargeFile() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
            }
        }
    }

    @Test(.tempFile("testReadRange.txt", contentSize: 326_000))
    func testReadRange() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=100-3999"]) { response in
                let slice = TempFileTrait.file.contents.getSlice(at: 100, length: 3900)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 100-3999/326000")
                #expect(response.headers[.contentLength] == "3900")
                #expect(response.headers[.contentType] == "text/plain")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=0-0"]) { response in
                let slice = TempFileTrait.file.contents.getSlice(at: 0, length: 1)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 0-0/326000")
                #expect(response.headers[.contentLength] == "1")
                #expect(response.headers[.contentType] == "text/plain")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=-3999"]) { response in
                let slice = TempFileTrait.file.contents.getSlice(at: 0, length: 4000)
                #expect(response.body == slice)
                #expect(response.headers[.contentLength] == "4000")
                #expect(response.headers[.contentRange] == "bytes 0-3999/326000")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=6000-"]) { response in
                let slice = TempFileTrait.file.contents.getSlice(at: 6000, length: 320_000)
                #expect(response.body == slice)
                #expect(response.headers[.contentLength] == "320000")
                #expect(response.headers[.contentRange] == "bytes 6000-325999/326000")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=500-100"]) { response in
                #expect(response.status == .rangeNotSatisfiable)
            }
        }
    }

    @Test(.tempFile(.randomNameWithExtension("txt"), contentSize: 10000))
    func testIfRangeRead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let (eTag, modificationDate) = try await client.execute(
                uri: TempFileTrait.file.path,
                method: .get,
                headers: [.range: "bytes=-3999"]
            ) {
                response -> (String, String) in
                let eTag = try #require(response.headers[.eTag])
                let modificationDate = try #require(response.headers[.lastModified])
                let slice = TempFileTrait.file.contents.getSlice(at: 0, length: 4000)
                #expect(response.body == slice)
                #expect(response.headers[.contentRange] == "bytes 0-3999/10000")
                return (eTag, modificationDate)
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=4000-", .ifRange: eTag]) {
                response in
                #expect(response.headers[.contentRange] == "bytes 4000-9999/10000")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=4000-", .ifRange: modificationDate]) {
                response in
                #expect(response.headers[.contentRange] == "bytes 4000-9999/10000")
            }

            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.range: "bytes=4000-", .ifRange: "not valid"]) {
                response in
                #expect(response.headers[.contentRange] == nil)
            }
        }
    }

    @Test(.tempFile("testHead.txt", contents: "Test file contents"))
    func testHead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        let date = Date()

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                #expect(response.body.readableBytes == 0)
                #expect(response.headers[.contentLength] == TempFileTrait.file.contents.readableBytes.description)
                #expect(response.headers[.contentType] == "text/plain")
                let responseDateString = try #require(response.headers[.lastModified])
                let responseDate = try #require(Self.rfc9110Formatter.date(from: responseDateString))
                #expect(date < responseDate + 10 && date > responseDate - 10)
            }
        }
    }

    @Test(.tempFile())
    func testETag() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let eTag = try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                try #require(response.headers[.eTag])
            }
            try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                #expect(response.headers[.eTag] == eTag)
            }
        }
    }

    @Test(.tempFile())
    func testIfNoneMatch() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let eTag = try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                try #require(response.headers[.eTag])
            }
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.ifNoneMatch: eTag]) { response in
                #expect(response.status == .notModified)
            }
            var headers: HTTPFields = .init()
            headers[values: .ifNoneMatch] = ["test", "\(eTag)"]
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: headers) { response in
                #expect(response.status == .notModified)
            }
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.ifNoneMatch: "dummyETag"]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test(.tempFile())
    func testIfModifiedSince() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let modifiedDate = try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                try #require(response.headers[.lastModified])
            }
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.ifModifiedSince: modifiedDate]) { response in
                #expect(response.status == .notModified)
            }
            // one minute before current date
            let date = Self.rfc9110Formatter.string(from: Date(timeIntervalSinceNow: -60))
            try await client.execute(uri: TempFileTrait.file.path, method: .get, headers: [.ifModifiedSince: date]) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test(
        .tempFile(.randomNameWithExtension("txt")),
        arguments: [
            ([CacheControl.Value.maxAge(60 * 60 * 24 * 30)], "max-age=2592000"),
            ([.maxAge(60 * 60 * 24 * 15), .private], "max-age=1296000, private"),
            ([.noStore], "no-store"),
            ([.noCache, .public], "no-cache, public"),
        ]
    )
    func testCacheControl(cacheControlValues: [CacheControl.Value], header: String) async throws {
        let router = Router()
        let cacheControl: CacheControl = .init([
            (.text, cacheControlValues),
            (.imageJpeg, [.maxAge(60 * 60 * 24 * 30), .private]),
        ])
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder, cacheControl: cacheControl))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.headers[.cacheControl] == header)
            }
        }
    }

    @Test(.tempFile("index.html"))
    func testIndexHtml() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder, searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
            }
        }
    }

    /// Test folder redirects to folder with "/" at the end of the name
    @Test(.tempFile("testFolderRedirect/index.html"))
    func testFolderRedirect() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder, searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/testFolderRedirect", method: .get) { response in
                #expect(response.status == .movedPermanently)
                #expect(response.headers[.location] == "/testFolderRedirect/")
            }
        }
    }

    @Test(.tempFile())
    func testSymlink() async throws {
        let symLink = FilePath(TempFolderTrait.folder).appending("testSymlink.html")
        try await FileSystem.shared.createSymbolicLink(at: symLink, withDestination: .init(TempFileTrait.file.path))
        do {
            let router = Router()
            router.middlewares.add(
                FileMiddleware(
                    fileProvider: LocalFileSystem(
                        rootFolder: TempFolderTrait.folder,
                        options: .allowSymbolicLinks,
                        logger: Logger(label: "LocalFileSystem")
                    ),
                    searchForIndexHtml: true
                )
            )
            let app = Application(responder: router.buildResponder())

            try await app.test(.router) { client in
                try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                    #expect(response.body == TempFileTrait.file.contents)
                }

                try await client.execute(uri: "/testSymlink.html", method: .get) { response in
                    #expect(response.body == TempFileTrait.file.contents)
                }
            }

            let router2 = Router()
            router2.middlewares.add(
                FileMiddleware(
                    fileProvider: LocalFileSystem(
                        rootFolder: TempFolderTrait.folder,
                        options: [],
                        logger: Logger(label: "LocalFileSystem")
                    ),
                    searchForIndexHtml: true
                )
            )
            let app2 = Application(responder: router2.buildResponder())
            try await app2.test(.router) { client in
                try await client.execute(uri: "/testSymlink.html", method: .get) { response in
                    #expect(response.status == .notFound)
                }
            }

            try await FileSystem.shared.removeItem(at: symLink)
        } catch {
            try await FileSystem.shared.removeItem(at: symLink)
            throw error
        }
    }

    @Test(.tempFile("ThrowCustom404.html"))
    func testOnThrowCustom404() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder, searchForIndexHtml: true))
        struct Custom404Error: HTTPResponseError {
            var status: HTTPResponse.Status { .notFound }

            func response(from request: Request, context: some RequestContext) throws -> Response {
                Response(status: self.status)
            }
        }
        router.get("/ThrowCustom404.html") { _, _ -> String in
            throw Custom404Error()
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/ThrowCustom404.html", method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
            }
        }
    }

    @Test(.tempFile())
    func testOnReturnNotFoundResponse() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder).withServeOnNotFoundResponse())
        router.get(.init(TempFileTrait.file.path)) { _, _ in
            Response(status: .notFound)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.status == .ok)
                #expect(response.body == TempFileTrait.file.contents)
            }
        }
    }

    @Test func testOnReturnNotFoundResponseFallsBackWhenFileMissing() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder).withServeOnNotFoundResponse())
        router.get("testOnReturnNotFoundResponseFallsBack.html") { _, _ in
            Response(status: .notFound, body: .init(byteBuffer: .init(string: "custom not found")))
        }
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/testOnReturnNotFoundResponseFallsBack.html", method: .get) { response in
                #expect(response.status == .notFound)
                #expect(String(buffer: response.body) == "custom not found")
            }
        }
    }

    @Test(.tempFile())
    func testOnReturnNotFoundResponseDisabledByDefault() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        router.get(.init(TempFileTrait.file.path)) { _, _ in
            Response(status: .notFound)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: "/\(TempFileTrait.file.path)", method: .get) { response in
                #expect(response.status == .notFound)
                #expect(response.body.readableBytes == 0)
            }
        }
    }

    @Test(.tempFile())
    func testOnReturnNotFoundResponseHead() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder).withServeOnNotFoundResponse())
        router.get(.init(TempFileTrait.file.path)) { _, _ in
            Response(status: .notFound)
        }
        let app = Application(responder: router.buildResponder())
        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .head) { response in
                #expect(response.status == .ok)
                #expect(response.body.readableBytes == 0)
                #expect(response.headers[.contentLength] == String(describing: TempFileTrait.file.contents.readableBytes))
            }
        }
    }

    @Test func testFolder() async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder, searchForIndexHtml: false))
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

    @Test func testETagString() async throws {
        // use memory file provider so we have a constant modification date.
        // Returns file name as contents of file
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
        router.add(middleware: FileMiddleware(fileProvider: MemoryFileProvider(prefix: "memory:/"), searchForIndexHtml: true))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: "/test/hello", method: .get) { response in
                #expect(String(buffer: response.body) == "memory://test/hello")
                #expect(response.headers[.eTag] == "W/\"1c36323133353736393630302e302d31\"")
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
    func testFilesWithNonLowercaseFileExtensions(filename: String) async throws {
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            let localFilename = FilePath(TempFolderTrait.folder).appending(filename)
            try await self.withFile(localFilename, contents: [UInt8]([65, 66, 67, 68])) {
                try await client.execute(uri: filename, method: .get) { response in
                    #expect(response.status == .ok)
                    #expect(response.headers[.contentType] == "image/jpeg")
                }
            }
        }
    }

    @Test(
        .tempFile(
            .randomNameWithExtension("m3u8"),
            contents: """
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
        )
    )
    func testCustomMIMEType() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder).withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8"))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/x-mpegurl"])
                #expect(validTypes.contains(contentType))
            }
        }
    }

    @Test(.tempFile(.randomNameWithExtension("m3U8")))
    func testCustomMIMETypeCaseInsensitivity() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        router.middlewares.add(FileMiddleware(TempFolderTrait.folder).withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8"))
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/x-mpegurl"])
                #expect(response.body == TempFileTrait.file.contents)
                #expect(validTypes.contains(contentType))
            }
        }
    }

    @Test(
        .tempFile(
            .randomNameWithExtension("m3u8"),
            contents: """
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
        )
    )
    func testCustomMIMETypes() async throws {
        let hlsStream = try #require(MediaType(from: "application/x-mpegURL"))
        let router = Router()
        let fileMiddleware = FileMiddleware<BasicRequestContext, LocalFileSystem>(TempFolderTrait.folder)
            .withAdditionalMediaType(hlsStream, mappedToFileExtension: "m3u8")
            .withAdditionalMediaTypes(forFileExtensions: [
                "foo": MediaType(type: .any, subType: "x-foo"),
                "M3U8": MediaType(type: .application, subType: "vnd.apple.mpegURL"),
            ])
        router.middlewares.add(fileMiddleware)
        let app = Application(responder: router.buildResponder())

        try await app.test(.router) { client in
            try await client.execute(uri: TempFileTrait.file.path, method: .get) { response in
                #expect(response.body == TempFileTrait.file.contents)
                let contentType = try #require(response.headers[.contentType])
                let validTypes = Set(["application/vnd.apple.mpegurl", "application/vnd.apple.mpegURL"])
                #expect(validTypes.contains(contentType))
            }
        }
    }
}
