@testable import Hummingbird
import XCTest

extension Application {
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
        let app = Application()
        app.ext = 56
        XCTAssertEqual(app.ext, 56)
    }

    func testExtensionShutdown() throws {
        let app = Application()
        let test = Application.ActiveTest()
        app.shutdownTest = test
        try app.shutdownApplication()
        XCTAssertEqual(test.active, false)
    }
}
