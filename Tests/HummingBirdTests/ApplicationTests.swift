import XCTest
import AsyncHTTPClient
@testable import HummingBird

enum ApplicationTestError: Error {
    case noBody
}

final class ApplicationTests: XCTestCase {

    func testConfiguration() {
        var configuration = Configuration()
        configuration["TEST_ENV"] = "testing"
        XCTAssertEqual(configuration["TEST_ENV"], "testing")
        configuration["TEST_ENV"] = nil
        XCTAssertEqual(configuration["TEST_ENV"], nil)
    }

    func testEnvironmentVariable() {
        setenv("TEST_VAR", "TRUE", 1)
        let configuration = Configuration()
        XCTAssertEqual(configuration["TEST_VAR"], "TRUE")
    }

    func createApp(_ configuration: Configuration = Configuration()) -> Application {
        let app = Application(configuration: configuration)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.router.get("/accepted") { request -> HTTPResponseStatus in
            return .accepted
        }
        app.router.post("/hello") { request -> ByteBuffer in
            return request.allocator.buffer(string: "POST: Hello")
        }
        app.router.get("/query") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: request.uri.query.map { String($0) } ?? "")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.router.post("/echo-body") { request -> Response in
            let body: ResponseBody = request.body.map { .byteBuffer($0) } ?? .empty
            return .init(status: .ok, headers: [:], body: body)
        }
        app.router.post("/echo-body-streaming") { request -> EventLoopFuture<Response> in
            let body: ResponseBody
            if var requestBody = request.body {
                body = .streamCallback { eventLoop in
                    let bytesToDownload = min(32*1024, requestBody.readableBytes)
                    guard bytesToDownload > 0 else { return eventLoop.makeSucceededFuture(.end) }
                    let buffer = requestBody.readSlice(length: bytesToDownload)!
                    return eventLoop.makeSucceededFuture(.byteBuffer(buffer))
                }
            } else {
                body = .empty
            }
            return request.eventLoop.makeSucceededFuture(.init(status: .ok, headers: [:], body: body))
        }
        return app
    }

    func shutdownApp(_ app: Application) {
        app.lifecycle.shutdown()
        app.lifecycle.wait()
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testRequest(_ request: HTTPClient.Request, app: Application? = nil, test: @escaping (HTTPClient.Response) throws -> ()) {
        let localApp: Application
        if let app = app {
            localApp = app
        } else {
            localApp = createApp(["port": Int.random(in: 10000...15000).description])
            DispatchQueue.global().async {
                localApp.serve()
            }
        }
        defer { if app == nil { shutdownApp(localApp) } }
        let requestURL = request.url.absoluteString.replacingOccurrences(of: "*", with: localApp.configuration.port.description)
        let request = try! HTTPClient.Request(url: requestURL, method: request.method, headers: request.headers, body: request.body)
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let response = client.execute(request: request)
            .flatMapThrowing { response in
                try test(response)
            }
        XCTAssertNoThrow(try response.wait())
    }

    func testGetRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "GET: Hello")
        }
    }

    func testHTTPStatusRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/accepted", method: .GET, headers: [:])
        testRequest(request) { response in
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testPostRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .POST, headers: [:])
        testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "POST: Hello")
        }
    }

    func testQueryRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/query?test=test%20data", method: .GET, headers: [:])
        testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "test=test%20data")
        }
    }

    func testResponseBody() {
        let buffer = randomBuffer(size: 140000)
        let request = try! HTTPClient.Request(url: "http://localhost:*/echo-body", method: .POST, headers: [:], body: .byteBuffer(buffer))
        testRequest(request) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    func testResponseBodyStreaming() {
        let buffer = randomBuffer(size: 140000)
        let request = try! HTTPClient.Request(url: "http://localhost:*/echo-body-streaming", method: .POST, headers: [:], body: .byteBuffer(buffer))
        testRequest(request) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    func testMiddleware() {
        struct TestMiddleware: Middleware {
            func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
                return next.respond(to: request).map { response in
                    var response = response
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        let app = createApp(["port": Int.random(in: 10000...15000).description])
        defer { shutdownApp(app) }
        DispatchQueue.global().async {
            app.serve()
        }

        app.middlewares.add(TestMiddleware())
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        testRequest(request, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    func testGroupMiddleware() {
        struct TestMiddleware: Middleware {
            func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
                return next.respond(to: request).map { response in
                    var response = response
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        let app = createApp(["port": Int.random(in: 10000...15000).description])
        DispatchQueue.global().async {
            app.serve()
        }
        defer { shutdownApp(app) }

        let group = app.router.group()
            .add(middleware: TestMiddleware())
        group.get("/group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        app.router.get("/not-group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }

        let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.port)/group", method: .GET, headers: [:])
        testRequest(request, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
        let request2 = try! HTTPClient.Request(url: "http://localhost:*/not-group", method: .GET, headers: [:])
        testRequest(request2, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, nil)
        }
    }
}
