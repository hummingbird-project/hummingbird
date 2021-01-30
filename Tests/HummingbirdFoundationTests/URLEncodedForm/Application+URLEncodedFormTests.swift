import Hummingbird
import HummingbirdFoundation
import HummingbirdXCT
import XCTest

class HummingBirdURLEncodedTests: XCTestCase {
    struct User: HBResponseCodable {
        let name: String
        let email: String
        let age: Int
    }

    struct Error: Swift.Error {}

    func testDecode() {
        let app = HBApplication(testing: .embedded)
        app.decoder = URLEncodedFormDecoder()
        app.router.put("/user") { request -> HTTPResponseStatus in
            guard let user = try? request.decode(as: User.self) else { throw HBHTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        app.XCTStart()
        defer { app.XCTStop() }

        let body = "name=John%20Smith&email=john.smith%40email.com&age=25"
        app.XCTExecute(uri: "/user", method: .PUT, body: ByteBufferAllocator().buffer(string: body)) {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func testEncode() {
        let app = HBApplication(testing: .embedded)
        app.encoder = URLEncodedFormEncoder()
        app.router.get("/user") { _ -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/user", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            let bodyString = try XCTUnwrap(body.readString(length: body.readableBytes))
            let user = try URLEncodedFormDecoder().decode(User.self, from: bodyString)
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
        }
    }
}
