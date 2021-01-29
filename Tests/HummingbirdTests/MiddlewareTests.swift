import Hummingbird
import HummingbirdXCT
import XCTest

final class MiddlewareTests: XCTestCase {
    func testMiddleware() {
        struct TestMiddleware: HBMiddleware {
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    response.headers.replaceOrAdd(name: "middleware", value: "TestMiddleware")
                    return response
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware())
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        }
    }

    func testMiddlewareOrder() {
        struct TestMiddleware: HBMiddleware {
            let string: String
            func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
                return next.respond(to: request).map { response in
                    response.headers.add(name: "middleware", value: string)
                    return response
                }
            }
        }
        let app = HBApplication(testing: .embedded)
        app.middleware.add(TestMiddleware(string: "first"))
        app.middleware.add(TestMiddleware(string: "second"))
        app.router.get("/hello") { _ -> String in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/hello", method: .GET) { response in
            // headers come back in opposite order as middleware is applied to responses in that order
            XCTAssertEqual(response.headers["middleware"].first, "second")
            XCTAssertEqual(response.headers["middleware"].last, "first")
        }
    }
}
