@testable import Hummingbird
import XCTest

extension HBApplication {
    class ActiveTest {
        var active: Bool
        init() {
            active = true
        }
    }

    var ext: Int? {
        get { return extensions.get(\.ext) }
        set { extensions.set(\.ext, value: newValue) }
    }

    var shutdownTest: ActiveTest? {
        get { return extensions.get(\.shutdownTest) }
        set {
            extensions.set(\.shutdownTest, value: newValue) { value in
                value?.active = false
            }
        }
    }
}

class ExtensionTests: XCTestCase {
    func testExtension() {
        let app = HBApplication()
        app.ext = 56
        XCTAssertEqual(app.ext, 56)
    }

    func testExtensionShutdown() throws {
        let app = HBApplication()
        let test = HBApplication.ActiveTest()
        app.shutdownTest = test
        try app.shutdownApplication()
        XCTAssertEqual(test.active, false)
    }
}
