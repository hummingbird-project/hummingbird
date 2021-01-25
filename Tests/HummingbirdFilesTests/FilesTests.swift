import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdFiles
import XCTest

class HummingbirdFilesTests: XCTestCase {

    func testGet() {
        let app = HBApplication(configuration: .init(address: .hostname(port: Int.random(in: 4000..<9000))))
        app.middlewares.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let future = client.get(url: "http://localhost:\(app.configuration.address.port!)/test.txt").flatMapThrowing { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), text)
        }
        XCTAssertNoThrow(try future.wait())
    }

    func testHead() throws {
        let app = HBApplication(configuration: .init(address: .hostname(port: Int.random(in: 4000..<9000))))
        app.middlewares.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.start()
        defer { app.stop(); app.wait() }

        let client = HTTPClient(eventLoopGroupProvider: .shared(app.eventLoopGroup))
        defer { XCTAssertNoThrow(try client.syncShutdown()) }

        let request = try HTTPClient.Request(url: "http://localhost:\(app.configuration.address.port!)/test.txt", method: .HEAD)
        let future = client.execute(request: request).flatMapThrowing { response in
            XCTAssertEqual(response.headers["Content-Length"].first, text.utf8.count.description)
        }
        XCTAssertNoThrow(try future.wait())
    }
}

