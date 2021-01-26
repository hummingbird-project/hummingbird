import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

enum ApplicationTestError: Error {
    case noBody
}

final class ApplicationTests: XCTestCase {

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

    func testGetRoute() throws {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: "GET: Hello")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.XCTStart()
        defer { app.stop() }
        
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
        defer { app.stop() }
        
        app.XCTExecute(uri: "/accepted", method: .GET) { response in
            XCTAssertEqual(response.status, .accepted)
        }
    }

    func testStandardHeaders() {
        let app = HBApplication(testing: .embedded)
        app.router.get("/hello") { request in
            return "Hello"
        }
        app.XCTStart()
        defer { app.stop() }
        
        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["connection"].first, "keep-alive")
            XCTAssertEqual(response.headers["content-length"].first, "5")
        }
    }

    func testPostRoute() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/hello") { request -> String in
            return "POST: Hello"
        }
        app.XCTStart()
        defer { app.stop() }
        
        app.XCTExecute(uri: "/hello", method: .POST) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "POST: Hello")
        }
    }

    func testQueryRoute() {
        let app = HBApplication(testing: .embedded)
        app.router.get("/query") { request -> EventLoopFuture<ByteBuffer> in
            let buffer = request.allocator.buffer(string: request.uri.query.map { String($0) } ?? "")
            return request.eventLoop.makeSucceededFuture(buffer)
        }
        app.XCTStart()
        defer { app.stop() }
        
        app.XCTExecute(uri: "/query?test=test%20data", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "test=test%20data")
        }
    }

    func testResponseBody() {
        let app = HBApplication(testing: .embedded)
        app.router.post("/echo-body") { request -> HBResponse in
            let body: HBResponseBody = request.body.buffer.map { .byteBuffer($0) } ?? .empty
            return .init(status: .ok, headers: [:], body: body)
        }
        app.XCTStart()
        defer { app.stop() }
        
        let buffer = self.randomBuffer(size: 140_000)
        app.XCTExecute(uri: "/echo-body", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.body, buffer)
        }
    }

    func testResponseBodyStreaming() {
        let app = HBApplication(testing: .embedded)
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
        app.XCTStart()
        defer { app.stop() }
        
        let buffer = self.randomBuffer(size: 140_000)
        app.XCTExecute(uri: "/echo-body-streaming", method: .POST, body: buffer) { response in
            XCTAssertEqual(response.body, buffer)
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
        let app = HBApplication(testing: .embedded, configuration: .init(maxUploadSize: 65536))
        app.server.addChannelHandler(CreateErrorHandler())
        app.router.put("/accepted") { _ -> HTTPResponseStatus in
            return .accepted
        }
        app.XCTStart()
        defer { app.stop() }

        let buffer = self.randomBuffer(size: 32)
        app.XCTExecute(uri: "/accepted", method: .PUT, body: buffer) { response in
            XCTAssertEqual(response.status, .insufficientStorage)
        }
    }

    func testLargeUploadLimit() {
        let app = HBApplication(testing: .embedded, configuration: .init(maxUploadSize: 65536))
        app.router.put("/upload") { _ -> HTTPResponseStatus in
            return .accepted
        }
        app.XCTStart()
        defer { app.stop() }
        
        let buffer = self.randomBuffer(size: 140_000)
        app.XCTExecute(uri: "/upload", method: .PUT, body: buffer) { response in
            XCTAssertEqual(response.status, .payloadTooLarge)
        }
    }

}
