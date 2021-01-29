import ExtrasBase64
import Hummingbird
import XCTest

class AuthenticationTests: XCTestCase {
    func testBasicAuthentication() {
        let app = HBApplication(testing: .embedded, configuration: .init(maxUploadSize: 65536))
        app.router.get("/authenticate") { request -> [String] in
            guard let basic = request.auth.basic else { throw HBHTTPError(.unauthorized) }
            return [basic.username, basic.password]
        }
        app.XCTStart()
        defer { app.XCTStop() }

        let basic = "adamfowler:testpassword"
        let basicHeader = "Basic \(String(base64Encoding: basic.utf8))"
        app.XCTExecute(uri: "/authenticate", method: .GET, headers: ["Authorization": basicHeader]) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), #"["adamfowler", "testpassword"]"#)
        }
    }

    func testBearerAuthentication() {
        let app = HBApplication(testing: .embedded, configuration: .init(maxUploadSize: 65536))
        app.router.get("/authenticate") { request -> String? in
            return request.auth.bearer?.token
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(
            uri: "/authenticate",
            method: .GET,
            headers: ["Authorization": "Bearer jh345jjefgi34rj"]
        ) { response in
            let body = try XCTUnwrap(response.body)
            XCTAssertEqual(String(buffer: body), "jh345jjefgi34rj")
        }
    }

    func testAuthenticator() {
        struct MyAuthenticator: HBAuthenticator {
            func authenticate(request: HBRequest) -> EventLoopFuture<Void> {
                guard let basic = request.auth.basic else { return request.success(()) }
                if basic.username == "adamfowler", basic.password == "password" {
                    request.auth.login(basic)
                }
                return request.success(())
            }
        }
        let app = HBApplication(testing: .embedded, configuration: .init(maxUploadSize: 65536))
        app.middleware.add(MyAuthenticator())
        app.router.get("/authenticate") { request -> HTTPResponseStatus in
            return request.auth.has(BasicAuthentication.self) ? .ok : .unauthorized
        }
        app.XCTStart()
        defer { app.XCTStop() }

        do {
            let basic = "adamfowler:nopassword"
            let basicHeader = "Basic \(String(base64Encoding: basic.utf8))"
            app.XCTExecute(uri: "/authenticate", method: .GET, headers: ["Authorization": basicHeader]) { response in
                XCTAssertEqual(response.status, .unauthorized)
            }
        }

        do {
            let basic = "adamfowler:password"
            let basicHeader = "Basic \(String(base64Encoding: basic.utf8))"
            app.XCTExecute(uri: "/authenticate", method: .GET, headers: ["Authorization": basicHeader]) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
    }
}
