import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdFiles
import HummingbirdXCT
import XCTest

class HummingbirdFilesTests: XCTestCase {

    func testGet() {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop(); }

        app.XCTExecute(uri: "/test.txt", method: .GET) { response in
            var body = try XCTUnwrap(response.body)
            XCTAssertEqual(body.readString(length: body.readableBytes), text)
        }
    }

    func testHead() throws {
        let app = HBApplication(testing: .live)
        app.middleware.add(HBFileMiddleware(".", application: app))

        let text = "Test file contents"
        let data = Data(text.utf8)
        let fileURL = URL(fileURLWithPath: "test.txt")
        XCTAssertNoThrow(try data.write(to: fileURL))
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL)) }

        app.XCTStart()
        defer { app.XCTStop(); }

        app.XCTExecute(uri: "/test.txt", method: .HEAD) { response in
            XCTAssertNil(response.body)
            XCTAssertEqual(response.headers["Content-Length"].first, text.utf8.count.description)
        }
    }
}

