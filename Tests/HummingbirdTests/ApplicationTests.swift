import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

final class ApplicationTests: XCTestCase {
    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testGetRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "GET: Hello")
        }
    }

    func testHTTPStatusRoute() {
        let app = HBApplication(testing: .embedded)
        app.router.get("/accepted") { _ -> HTTPResponseStatus in
            return .accepted
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/accepted", method: .GET) { response in
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testStandardHeaders() {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { _ in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["connection"].first, "keep-alive")
            XCTAssertEqual(response.headers["content-length"].first, "5")
        }
    }

    func testServerHeaders() {
        let app = HBApplication(testing: .embedded, configuration: .init(serverName: "Hummingbird"))
        app.router.get("/hello") { _ in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["server"].first, "Hummingbird")
        }
    }

    func testPostRoute() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/hello") { _ -> String in
            return "POST: Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .POST) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "POST: Hello")
        }
    }

    func testMultipleMethods() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/hello") { _ -> String in
            return "POST"
        }
        app.router.get("/hello") { _ -> String in
            return "GET"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }
        app.XCTExecute(uri: "/hello", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "POST")
        }
    }

    func testMultipleGroupMethods() {
        let app = HBApplication(testing: .embedded)
        app.router.group("hello")
            .post { _ -> String in
                return "POST"
            }
            .get { _ -> String in
                return "GET"
            }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "GET")
        }
        app.XCTExecute(uri: "/hello", method: .POST) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "POST")
        }
    }

    func testQueryRoute() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/query") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: request.uri.queryParameters["test"].map { String($0) } ?? "")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/query?test=test%20data%C3%A9", method: .POST) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "test dataé")
        }
    }

    func testArray() {
        let app = HBApplication(testing: .embedded)
        app.router.get("array") { _ -> [String] in
            return ["yes", "no"]
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/array", method: .GET) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
        }
    }

    func testEventLoopFutureArray() {
        let app = HBApplication(testing: .embedded)
        app.router.patch("array") { request -> EventLoopFuture<[String]> in
            return request.success(["yes", "no"])
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/array", method: .PATCH) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "[\"yes\", \"no\"]")
        }
    }

    func testResponseBody() {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/echo-body")
            .post { request -> HBResponse in
                let body: HBResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
                return .init(status: .ok, headers: [:], body: body)
            }
        app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 1_140_000)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    func testOptional() {
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/echo-body")
            .post { request -> ByteBuffer? in
                return request.body.buffer
            }
        app.XCTStart()
        defer { app.XCTStop() }

        let buffer = self.randomBuffer(size: 64)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body, buffer)
        }
        app.XCTExecute(uri: "/echo-body", method: .POST) { response in
            XCTAssertEqual(response.status, .notFound)
        }
    }

    func testOptionalCodable() {
        struct Name: HBResponseCodable {
            let first: String
            let last: String
        }
        let app = HBApplication(testing: .embedded)
        app.router
            .group("/name")
            .patch { _ -> Name? in
                return Name(first: "john", last: "smith")
            }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/name", method: .PATCH) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), #"Name(first: "john", last: "smith")"#)
        }
    }

    func testEditResponse() throws {
        let app = HBApplication(testing: .embedded)
        app.router.delete("/hello") { request -> String in
            request.response.headers.add(name: "test", value: "value")
            request.response.status = .imATeapot
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .DELETE) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .imATeapot)
            XCTAssertEqual(response.headers["test"].first, "value")
            XCTAssertEqual(string, "Hello")
        }
    }
}
