import AsyncHTTPClient
import Hummingbird
import HummingbirdXCT
import NIOExtras
import NIOHTTP1
import XCTest

enum ApplicationTestError: Error {
    case noBody
}

final class ApplicationTests: XCTestCase {

    func testApp(configuration: HBApplication.Configuration = .init(address: .hostname(port: Int.random(in: 4000..<9000))) , callback: (HBApplication, HTTPClient) throws -> ()) {
        let app = HBApplication(configuration: configuration)
        defer {
            app.stop()
            app.wait()
            Thread.sleep(forTimeInterval: 0.5)
        }
        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown())}

        XCTAssertNoThrow(try callback(app, client))
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func testEnvironment() {
        var env = HBEnvironment()
        env.set("TEST_ENV", value: "testing")
        XCTAssertEqual(env.get("TEST_ENV"), "testing")
        env.set("TEST_ENV", value: nil)
        XCTAssertEqual(env.get("TEST_ENV"), nil)
    }

    func testEnvironmentVariable() {
        setenv("TEST_VAR", "TRUE", 1)
        let env = HBEnvironment()
        XCTAssertEqual(env.get("TEST_VAR"), "TRUE")
    }

    func testStartStop() {
        testApp { app, _ in app.start() }
    }

    func testGetRoute() throws {
        let app = HBApplication(.testing)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        XCTAssertNoThrow(try app.XCTTestResponse(.init(uri: "/hello", method: .GET)) { response in
            var body = response.body
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "GET: Hello")
        })
    }

    func testHTTPStatusRoute() {
        testApp { app, client in
            app.router.get("/accepted") { _ -> HTTPResponseStatus in
                return .accepted
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.server.configuration.address.port!)/accepted", method: .GET, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.status, .accepted)
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testStandardHeaders() {
        testApp { app, client in
            app.router.get("/hello") { request in
                return "Hello"
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/hello", method: .GET, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.headers["connection"].first, "keep-alive")
                    XCTAssertEqual(response.headers["content-length"].first, "5")
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testPostRoute() {
        testApp { app, client in
            app.router.post("/hello") { request -> String in
                return "POST: Hello"
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/hello", method: .POST, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    guard var body = response.body else { throw ApplicationTestError.noBody }
                    let string = body.readString(length: body.readableBytes)
                    XCTAssertEqual(response.status, .ok)
                    XCTAssertEqual(string, "POST: Hello")
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testQueryRoute() {
        testApp { app, client in
            app.router.get("/query") { request -> EventLoopFuture<ByteBuffer> in
                let buffer = request.allocator.buffer(string: request.uri.query.map { String($0) } ?? "")
                return request.eventLoop.makeSucceededFuture(buffer)
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/query?test=test%20data", method: .GET, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    guard var body = response.body else { throw ApplicationTestError.noBody }
                    let string = body.readString(length: body.readableBytes)
                    XCTAssertEqual(response.status, .ok)
                    XCTAssertEqual(string, "test=test%20data")
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testResponseBody() {
        testApp { app, client in
            app.router.post("/echo-body") { request -> HBResponse in
                let body: HBResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
                return .init(status: .ok, headers: [:], body: body)
            }
            app.start()

            let buffer = self.randomBuffer(size: 140_000)
            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/echo-body", method: .POST, headers: [:], body: .byteBuffer(buffer))
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.body, buffer)
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testResponseBodyStreaming() {
        testApp { app, client in
            // stream request into response
            app.router.addStreamingRoute("/echo-body-streaming", method: .POST) { request -> EventLoopFuture<HBResponse> in
                let body: HBResponseBody = .streamCallback { eventLoop in
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
            app.start()

            let buffer = self.randomBuffer(size: 140_000)
            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/echo-body-streaming", method: .POST, headers: [:], body: .byteBuffer(buffer))
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.body, buffer)
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testMiddleware() {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        testApp { app, client in
            app.middlewares.add(TestMiddleware())
            app.router.get("/hello") { request -> String in
                return "Hello"
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/hello", method: .GET, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

    func testGroupMiddleware() {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        testApp { app, client in
            let group = app.router.group()
                .add(middleware: TestMiddleware())
            group.get("/group") { request in
                return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
            }
            app.router.get("/not-group") { request in
                return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
            }
            app.start()

            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/group", method: .GET, headers: [:])
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
                }
            XCTAssertNoThrow(try response.wait())
            let request2 = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/not-group", method: .GET, headers: [:])
            let response2 = client.execute(request: request2)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.headers["middleware"].first, nil)
                }
            XCTAssertNoThrow(try response2.wait())
        }
    }

    func testOrdering() {
        testApp { app, client in
            app.router.get("/wait/:time") { request -> EventLoopFuture<String> in
                let wait = request.parameters.get("time", as: Int64.self) ?? 0
                return request.eventLoop.scheduleTask(in: .milliseconds(wait)) {}.futureResult.map { String(wait) }
            }
            app.start()

            let responseFutures = (1...16).reversed().map { client.get(url: "http://localhost:\(app.configuration.address.port!)/wait/\($0 * 100)") }
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

    func testChannelHandlerErrorPropagation() {
        class CreateErrorHandler: ChannelInboundHandler {
            typealias InboundIn = HTTPServerRequestPart

            var seen: Bool = false
            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                let part = self.unwrapInboundIn(data)

                if case .body = part {
                    context.fireErrorCaught(HBHTTPError(.insufficientStorage))
                }
                context.fireChannelRead(data)
            }
        }
        let buffer = self.randomBuffer(size: 120_000)
        testApp { app, client in
            app.server.addChildChannelHandler(CreateErrorHandler(), position: .afterHTTP)
            app.router.put("/accepted") { _ -> HTTPResponseStatus in
                return .accepted
            }
            app.start()

            let response = client.put(url: "http://localhost:\(app.configuration.address.port!)/accepted", body: .byteBuffer(buffer))
                .flatMapThrowing { response in
                    XCTAssertEqual(response.status, .insufficientStorage)
                }
            XCTAssertNoThrow(try response.wait())
        }

    }

    func testLargeUploadLimit() {
        testApp(configuration: .init(maxUploadSize: 65536)) { app, client in
            app.router.post("/upload") { request -> HTTPResponseStatus in
                return .ok
            }
            app.start()

            let buffer = self.randomBuffer(size: 140_000)
            let request = try! HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/upload", method: .POST, headers: [:], body: .byteBuffer(buffer))
            let response = client.execute(request: request)
                .flatMapThrowing { response in
                    XCTAssertEqual(response.status, .payloadTooLarge)
                }
            XCTAssertNoThrow(try response.wait())
        }
    }

}
