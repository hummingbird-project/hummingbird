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

    func createApp() -> Application {
        let app = Application()
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.router.post("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "POST: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.router.get("/query") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: request.uri.queryParameters["test"].map { String($0) } ?? "")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        return app
    }

    func shutdownApp(_ app: Application) {
        app.lifecycle.shutdown()
        app.lifecycle.wait()
    }

    func testGetRoute() {
        let app = createApp()
        defer { shutdownApp(app) }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8000/hello", method: .GET, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                guard var body = response.body else { throw ApplicationTestError.noBody }
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "GET: Hello")
            }
        XCTAssertNoThrow(try response.wait())
    }

    func testPostRoute() {
        let app = createApp()
        defer { shutdownApp(app) }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8000/hello", method: .POST, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                guard var body = response.body else { throw ApplicationTestError.noBody }
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "POST: Hello")
            }
        XCTAssertNoThrow(try response.wait())
    }

    func testQueryRoute() {
        let app = createApp()
        defer { shutdownApp(app) }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8000/query?test=test%20data", method: .GET, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                guard var body = response.body else { throw ApplicationTestError.noBody }
                let string = body.readString(length: body.readableBytes)
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(string, "test%20data")
            }
        XCTAssertNoThrow(try response.wait())
    }

    func testWrongMethodRoute() {
        let app = createApp()
        defer { shutdownApp(app) }
        DispatchQueue.global().async {
            app.serve()
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let request = HTTPClient.Request(uri: "http://localhost:8000/hello2", method: .GET, headers: [:])
        let response = client.execute(request)
            .flatMapThrowing { response in
                XCTAssertEqual(response.status, .notFound)
            }
        XCTAssertNoThrow(try response.wait())
    }
}
