import Hummingbird
import HummingbirdXCT
import NIOHTTP1
import XCTest

final class AsyncTests: XCTestCase {
    func testAsyncRoute() {
        let app = HBApplication(testing: .live)
        app.router.get("/hello") { request -> ByteBuffer in
            let buffer = request.allocator.buffer(string: "Async Hello")
            return try await request.eventLoop.makeSucceededFuture(buffer).get()
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let string = body.readString(length: body.readableBytes)
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(string, "Async Hello")
        }
    }

    func testAsyncMiddleware() {
        struct AsyncTestMiddleware: HBAsyncMiddleware {
            func apply(to request: HBRequest, next: HBResponder) async throws -> HBResponse {
                let response = try await next.respond(to: request)
                response.headers.add(name: "async", value: "true")
                return response
            }
        }
        let app = HBApplication(testing: .live)
        app.middleware.add(AsyncTestMiddleware())
        app.router.get("/hello") { request -> String in
            "hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["async"].first, "true")
        }
    }
}
