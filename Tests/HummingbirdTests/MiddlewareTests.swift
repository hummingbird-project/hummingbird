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
        let app = HBApplication(.testing)
        app.middlewares.add(TestMiddleware())
        app.router.get("/hello") { request -> String in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        XCTAssertNoThrow(try app.XCTTestResponse(.init(uri: "/hello", method: .GET)) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        })
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
        let app = HBApplication(.testing)
        app.middlewares.add(TestMiddleware(string: "first"))
        app.middlewares.add(TestMiddleware(string: "second"))
        app.router.get("/hello") { request -> String in
            return "Hello"
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        XCTAssertNoThrow(try app.XCTTestResponse(.init(uri: "/hello", method: .GET)) { response in
            // headers come back in opposite order as middleware is applied to responses in that order
            XCTAssertEqual(response.headers["middleware"].first, "second")
            XCTAssertEqual(response.headers["middleware"].last, "first")
        })
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
        let app = HBApplication(.testing)
        let group = app.router.group()
            .add(middleware: TestMiddleware())
        group.get("/group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        app.router.get("/not-group") { request in
            return request.eventLoop.makeSucceededFuture(request.allocator.buffer(string: "hello"))
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        XCTAssertNoThrow(try app.XCTTestResponse(.init(uri: "/group", method: .GET)) { response in
            XCTAssertEqual(response.headers["middleware"].first, "TestMiddleware")
        })

        XCTAssertNoThrow(try app.XCTTestResponse(.init(uri: "/not-group", method: .GET)) { response in
            XCTAssertEqual(response.headers["middleware"].first, nil)
        })
    }

}
