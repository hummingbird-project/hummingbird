import AsyncHTTPClient
import Hummingbird
import HummingbirdJSON
import XCTest

class HummingBirdJSONTests: XCTestCase {
    struct User: ResponseCodable {
        let name: String
        let email: String
        let age: Int
    }
    struct Error: Swift.Error {}

    func testDecode() {
        let app = Application()
        app.decoder = JSONDecoder()
        app.router.put("/user") { request -> HTTPResponseStatus in
            guard let user = try? request.decode(as: User.self) else { throw HTTPError(.badRequest) }
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
            return .ok
        }
        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let body = #"{"name": "John Smith", "email": "john.smith@email.com", "age": 25}"#
        let response = client.put(url: "http://localhost:\(app.configuration.address.port!)/user", body: .string(body), deadline: .now() + .seconds(10))
        XCTAssertNoThrow(try response.wait())
    }

    func testEncode() {
        let app = Application()
        app.encoder = JSONEncoder()
        app.router.get("/user") { request -> User in
            return User(name: "John Smith", email: "john.smith@email.com", age: 25)
        }
        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let response = client.get(url: "http://localhost:\(app.configuration.address.port!)/user").flatMapThrowing { response in
            guard let body = response.body else { throw HummingBirdJSONTests.Error() }
            let user = try JSONDecoder().decode(User.self, from: body)
            XCTAssertEqual(user.name, "John Smith")
            XCTAssertEqual(user.email, "john.smith@email.com")
            XCTAssertEqual(user.age, 25)
        }
        XCTAssertNoThrow(try response.wait())
    }
}

