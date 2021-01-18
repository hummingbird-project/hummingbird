import AsyncHTTPClient
import HummingBird
import HummingBirdCompression
import XCTest

class HummingBirdCompressionTests: XCTestCase {
    func testDecode() {
        let app = Application(.init(host: "localhost", port: 8000))
        app.router.get("/hello") { request in
            return "hello"
        }
        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }
    }

}
