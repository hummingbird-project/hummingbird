import Foundation
import Hummingbird
import HummingbirdFoundation
import HummingbirdXCT
import XCTest

class HummingbirdDateTests: XCTestCase {
    func testGetDate() {
        let app = HBApplication(testing: .embedded)
        app.addFoundation()
        app.router.get("date") { request in
            return request.eventLoopStorage.dateCache.currentDate
        }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/date", method: .GET) { _ in
        }
    }

    func testDateResponseMiddleware() {
        let app = HBApplication(testing: .embedded)
        app.addFoundation()
        app.router.get("date") { _ in
            return "hello"
        }

        app.XCTStart()
        defer { app.XCTStop() }

        app.XCTExecute(uri: "/date", method: .GET) { response in
            XCTAssertNotNil(response.headers["date"].first)
        }
        app.XCTExecute(uri: "/date", method: .GET) { response in
            XCTAssertNotNil(response.headers["date"].first)
        }
    }
}
