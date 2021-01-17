import AsyncHTTPClient
import HummingBird
import NIOExtras
import NIOHTTP1
import XCTest

enum ApplicationTestError: Error {
    case noBody
}

final class ApplicationTests: XCTestCase {
    static var app: Application!
    static var httpServer: HTTPServer!
    
    class override func setUp() {
        app = createApp(.init(host: "localhost", port: 8000))
        #if DEBUG
        Self.httpServer.addChildChannelHandler(DebugInboundEventsHandler(), position: .afterHTTP)
        #endif
        app.start()
    }
    
    class override func tearDown() {
        app.stop()
        app.wait()
    }
    
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

    func testStartStop() {
        let app = Application()
        app.addHTTPServer()
        app.start()
        app.stop()
    }
    
    static func createApp(_ configuration: HTTPServer.Configuration) -> Application {
        struct TestMiddleware: Middleware {
            func apply(to request: Request, next: RequestResponder) -> EventLoopFuture<Response> {
                return next.respond(to: request).map { response in
                    var response = response
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }

        let app = Application()
        Self.httpServer = app.addHTTPServer(configuration)
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
        app.router.addStreamingRoute("/echo-body-streaming2", method: .POST) { request -> EventLoopFuture<Response> in
            let body: ResponseBody = .streamCallback { eventLoop in
                return request.body.stream.consume(on: request.eventLoop).map { output in
                    switch output {
                    case .byteBuffers(let buffers):
                        if var buffer = buffers.first {
                            for var b in buffers.dropFirst() {
                                buffer.writeBuffer(&b)
                            }
                            return .byteBuffer(buffer)
                        } else {
                            return .byteBuffer(request.allocator.buffer(capacity: 0))
                        }
                    case .end:
                        return .end
                    }
                }
            }
            return request.eventLoop.makeSucceededFuture(.init(status: .ok, headers: [:], body: body))
        }
        app.router.get("/wait/{time}") { request -> EventLoopFuture<String> in
            let wait = request.parameters.get("time", as: Int64.self) ?? 0
            return request.eventLoop.scheduleTask(in: .milliseconds(wait)) {}.futureResult.map { String(wait) }
        }
        let group = app.router.group()
            .add(middleware: TestMiddleware())
        group.get("/group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        app.router.get("/not-group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        return app
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testRequest(_ request: HTTPClient.Request, app: Application? = nil, client: HTTPClient? = nil, test: @escaping (HTTPClient.Response) throws -> Void) {
        let app: Application = app ?? Self.app
        let httpServer = app.servers.first?.value as! HTTPServer

        let requestURL = request.url.absoluteString.replacingOccurrences(of: "*", with: httpServer.configuration.port.description)
        let request = try! HTTPClient.Request(url: requestURL, method: request.method, headers: request.headers, body: request.body)

        let localClient: HTTPClient
        if let client = client {
            localClient = client
        } else {
            localClient = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
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

    func testRequestResponseBodyStreaming() {
        let buffer = self.randomBuffer(size: 180_400)
        let request = try! HTTPClient.Request(url: "http://localhost:*/echo-body-streaming2", method: .POST, headers: [:], body: .byteBuffer(buffer))
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
        let app = Self.createApp(.init(host: "localhost", port: 8080))
        app.middlewares.add(TestMiddleware())
        app.start()
        defer { app.stop(); app.wait() }

        Thread.sleep(forTimeInterval: 1)
        let request = try! HTTPClient.Request(url: "http://localhost:*/hello", method: .GET, headers: [:])
        self.testRequest(request, app: app) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    func testGroupMiddleware() {
        let request = try! HTTPClient.Request(url: "http://localhost:*/group", method: .GET, headers: [:])
        self.testRequest(request) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
        let request2 = try! HTTPClient.Request(url: "http://localhost:*/not-group", method: .GET, headers: [:])
        self.testRequest(request2) { response in
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
        let app = Self.createApp(.init(port: 8002))
        app.start()
        defer { app.stop(); app.wait() }
        
        let client = HTTPClient(eventLoopGroupProvider: .shared(Self.app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
        
        let responseFutures = (1...16).reversed().map { client.get(url: "http://localhost:8002/wait/\($0 * 100)") }
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
