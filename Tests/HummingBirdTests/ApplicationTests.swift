import XCTest
import HBHTTPClient
@testable import HummingBird

enum ApplicationTestError: Error {
    case noBody
}

final class ApplicationTests: XCTestCase {

    func testEnvironment() {
        Environment["TEST_ENV"] = "testing"
        XCTAssertEqual(Environment["TEST_ENV"], "testing")
        Environment["TEST_ENV"] = nil
        XCTAssertEqual(Environment["TEST_ENV"], nil)
    }

    func testGetRoute() {
        let app = Application()
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8080/hello", method: .GET, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                guard var body = response.body else { throw ApplicationTestError.noBody }
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "Hello")
            }
        XCTAssertNoThrow(try response.wait())

        app.lifecycle.shutdown()
        app.lifecycle.wait()
    }

    func testPostRoute() {
        let app = Application()
        app.router.post("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8080/hello", method: .POST, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                guard var body = response.body else { throw ApplicationTestError.noBody }
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "Hello")
            }
        XCTAssertNoThrow(try response.wait())

        app.lifecycle.shutdown()
        app.lifecycle.wait()

    }

    func testWrongMethodRoute() {
        let app = Application()
        app.router.post("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8080/hello", method: .GET, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .internalServerError)
            }
        XCTAssertNoThrow(try response.wait())

        app.lifecycle.shutdown()
        app.lifecycle.wait()

    }
}
