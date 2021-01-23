import Hummingbird
import HummingbirdJSON
import HummingbirdXCT
import XCTest

class HummingBirdJSONTests: XCTestCase {
    struct User: HBResponseCodable {
        let name: String
        let email: String
        let age: Int
    }
    struct Error: Swift.Error {}

    func testDecode() {
        let app = HBApplication(.testing)
        app.decoder = JSONDecoder()
        app.router.put("/user") { request -> HTTPResponseStatus in
            guard let user = try? request.decode(as: User.self) else { throw HBHTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        let body = #"{"name": "John Smith", "email": "john.smith@email.com", "age": 25}"#
        XCTAssertNoThrow(try app.XCTTestResponse(uri: "/user", method: .PUT, body: ByteBufferAllocator().buffer(string: body)) {
            XCTAssertEqual($0.status, .ok)
        })
    }

    func testEncode() {
        let app = HBApplication(.testing)
        app.encoder = JSONEncoder()
        app.router.get("/user") { request -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        app.XCTStart()
        defer { app.XCTStop() }
        
        XCTAssertNoThrow(try app.XCTTestResponse(uri: "/user", method: .GET) { response in
            let user = try? JSONDecoder().decode(User.self, from: response.body)
            XCTAssertEqual(user?.name, "John Smith")
            XCTAssertEqual(user?.email, "john.smith@email.com")
            XCTAssertEqual(user?.age, 25)
        })
    }
}

