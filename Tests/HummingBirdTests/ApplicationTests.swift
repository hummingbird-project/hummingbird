import AsyncHTTPClient
import HummingBird
import NIOExtras
import XCTest

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

    func createApp(_ configuration: HTTPServer.Configuration) -> Application {
        let app = Application()
        app.addHTTP(configuration)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.router.get("/accepted") { _ -> HTTPResponseStatus in
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
            let body: ResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
            return .init(status: .ok, headers: [:], body: body)
        }
        app.router.post("/echo-body-streaming") { request -> EventLoopFuture<Response> in
            let body: ResponseBody
            if var requestBody = request.body.buffer {
                body = .streamCallback { eventLoop in
                    let bytesToDownload = min(32 * 1024, requestBody.readableBytes)
                    guard bytesToDownload > 0 else { return eventLoop.makeSucceededFuture(.end) }
                    let buffer = requestBody.readSlice(length: bytesToDownload)!
                    return eventLoop.makeSucceededFuture(.byteBuffer(buffer))
                }
            } else {
                body = .empty
            }
            return request.eventLoop.makeSucceededFuture(.init(status: .ok, headers: [:], body: body))
        }
        app.router.get("/wait") { request -> EventLoopFuture<String> in
            let waitString = request.uri.queryParameters["time"] ?? "0"
            let wait = Int(waitString) ?? 0
            return request.eventLoop.scheduleTask(in: .milliseconds(Int64(wait))) {}.futureResult.map { String(waitString) }
        }
        return app
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testRequest(_ request: HTTPClient.Request, app: Application? = nil, client: HTTPClient? = nil, test: @escaping (HTTPClient.Response) throws -> Void) {
        let localApp: Application
        let httpServer: HTTPServer
        if let app = app {
            localApp = app
            httpServer = app.http!
        } else {
            localApp = self.createApp(.init(host: "localhost", port: Int.random(in: 10000...15000)))
            httpServer = localApp.http!
            #if DEBUG
            httpServer.addChildChannelHandler(DebugInboundEventsHandler(), position: .last)
            #endif
            DispatchQueue.global().async {
                localApp.serve()
            }
        }
        defer {
            if app == nil { localApp.syncShutdown() }
        }
        let requestURL = request.url.absoluteString.replacingOccurrences(of: "*", with: httpServer.configuration.port.description)
        let request = try! HTTPClient.Request(url: requestURL, method: request.method, headers: request.headers, body: request.body)

        let localClient: HTTPClient
        if let client = client {
            localClient = client
        } else {
            localClient = HTTPClient(eventLoopGroupProvider: .createNew)
        }
        defer {
            if client == nil { XCTAssertNoThrow(try localClient.syncShutdown()) }
        }

        let response = localClient.execute(request: request)
            .flatMapThrowing { response in
                try test(response)
            }
        XCTAssertNoThrow(try response.wait())
    }

    func testGetRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        self.testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "GET: Hello")
        }
    }

    func testHTTPStatusRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/accepted", method: .GET, headers: [:])
        self.testRequest(request) { response in
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testPostRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .POST, headers: [:])
        self.testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "POST: Hello")
        }
    }

    func testQueryRoute() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/query?test=test%20data", method: .GET, headers: [:])
        self.testRequest(request) { response in
            guard var body = response.body else { throw ApplicationTestError.noBody }
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "test=test%20data")
        }
    }

    func testResponseBody() {
        let buffer = self.randomBuffer(size: 140_000)
        let request = try! HTTPClient.Request(url: "http://localhost:*/echo-body", method: .POST, headers: [:], body: .byteBuffer(buffer))
        self.testRequest(request) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    func testResponseBodyStreaming() {
        let buffer = self.randomBuffer(size: 140_000)
        let request = try! HTTPClient.Request(url: "http://localhost:*/echo-body-streaming", method: .POST, headers: [:], body: .byteBuffer(buffer))
        self.testRequest(request) { response in
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
        let app = self.createApp(.init(host: "localhost", port: Int.random(in: 10000...15000)))
        defer { app.shutdown() }
        app.middlewares.add(TestMiddleware())
        DispatchQueue.global().async {
            app.serve()
        }

        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        self.testRequest(request, app: app) { response in
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
        let app = self.createApp(.init(host: "localhost", port: Int.random(in: 10000...15000)))
        let group = app.router.group()
            .add(middleware: TestMiddleware())
        group.get("/group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        app.router.get("/not-group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }

        DispatchQueue.global().async {
            app.serve()
        }
        defer { app.shutdown() }

        let request = try! HTTPClient.Request(url: "http://localhost:*/group", method: .GET, headers: [:])
        self.testRequest(request, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
        let request2 = try! HTTPClient.Request(url: "http://localhost:*/not-group", method: .GET, headers: [:])
        self.testRequest(request2, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, nil)
        }
    }

    func testKeepAlive() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        self.testRequest(request) { response in
            XCTAssertEqual(response.headers["connection"].first, "keep-alive")
        }
    }

    func testOrdering() {
        let app = self.createApp(.init(host: "localhost", port: Int.random(in: 10000...15000), enableHTTPPipelining: true))
        let httpServer = app.servers["HTTP"] as! HTTPServer

        DispatchQueue.global().async {
            app.serve()
        }
        defer {
            app.shutdown()
        }
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        let responseFutures = (1...16).reversed().map { client.get(url: "http://localhost:\(httpServer.configuration.port)/wait?time=\($0 * 100)") }
        let future = EventLoopFuture.whenAllComplete(responseFutures, on: client.eventLoopGroup.next()).map { results in
            for i in 0..<16 {
                let result = results[i]
                if case .success(let response) = result {
                    let string: String? = response.body.map { var buffer = $0; return buffer.readString(length: buffer.readableBytes)! }
                    XCTAssertEqual(string, "\((16 - i) * 100)")
                    return
                }
                XCTFail()
            }
        }
        XCTAssertNoThrow(try future.wait())
    }
}

extension Application {
    public func syncShutdown() {
        lifecycle.shutdown()
        lifecycle.wait()
    }
}
