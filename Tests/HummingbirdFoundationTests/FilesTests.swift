import AsyncHTTPClient
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

    func testRead() {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.jpg")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/test.jpg", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), text)
            XCTAssertEqual(response.headers["content-type"].first, "image/jpeg")
       }
    }

    func testReadLargeFile() {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let buffer = self.randomBuffer(size: 380_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/test.txt", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(body, buffer)
        }
    }

    func testReadRange() {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let buffer = self.randomBuffer(size: 326_000)
        let data = Data(buffer: buffer)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=100-3999"]) { response in
            let body = try XCTUnwrap(response.body)
            let slice = buffer.getSlice(at: 100, length: 3900)
            XCTAssertEqual(body, slice)
            XCTAssertEqual(response.headers["content-range"].first, "bytes 100-3999/326000")
            XCTAssertEqual(response.headers["content-type"].first, "text/plain")
        }

        app.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=-3999"]) { response in
            let body = try XCTUnwrap(response.body)
            let slice = buffer.getSlice(at: 0, length: 4000)
            XCTAssertEqual(body, slice)
            XCTAssertEqual(response.headers["content-range"].first, "bytes 0-3999/326000")
        }

        app.XCTExecute(uri: "/test.txt", method: .GET, headers: ["Range": "bytes=6000-"]) { response in
            let body = try XCTUnwrap(response.body)
            let slice = buffer.getSlice(at: 6000, length: 320_000)
            XCTAssertEqual(body, slice)
            XCTAssertEqual(response.headers["content-range"].first, "bytes 6000-325999/326000")
        }
    }

    func testHead() throws {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
            XCTAssertNil(response.body)
            XCTAssertEqual(response.headers["Content-Length"].first, text.utf8.count.description)
            XCTAssertEqual(response.headers["content-type"].first, "text/plain")
        }
    }

    func testWrite() throws {
        let filename = "testWrite.txt"
        let app = HBApplication(testing: .live)
        app.router.put("store") { request -> EventLoopFuture<HTTPResponseStatus> in
            let fileIO = HBFileIO(application: request.application)
            return fileIO.writeFile(contents: request.body, path: filename, context: request.context)
                .map { .ok }
        }

        app.XCTStart()
        defer { app.XCTStop() }

        let buffer = ByteBufferAllocator().buffer(string: "This is a test")
        app.XCTExecute(uri: "/store", method: .PUT, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
        }

        let fileURL = URL(fileURLWithPath: filename)
        let data = try Data(contentsOf: fileURL)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
        XCTAssertEqual(String(decoding: data, as: Unicode.UTF8.self), "This is a test")
    }

    func testWriteLargeFile() throws {
        let filename = "testWriteLargeFile.txt"
        let app = HBApplication(testing: .live)
        app.router.put("store") { request -> EventLoopFuture<HTTPResponseStatus> in
            let fileIO = HBFileIO(application: request.application)
            return fileIO.writeFile(contents: request.body, path: filename, context: request.context)
                .map { .ok }
        }

        app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 400_000)
        app.XCTExecute(uri: "/store", method: .PUT, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
        }

        let fileURL = URL(fileURLWithPath: filename)
        let data = try Data(contentsOf: fileURL)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }
        XCTAssertEqual(Data(buffer: buffer), data)
    }
}
