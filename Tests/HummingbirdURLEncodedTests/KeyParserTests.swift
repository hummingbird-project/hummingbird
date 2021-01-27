@testable import HummingbirdURLEncoded
import XCTest

class KeyParserTests: XCTestCase {
    func testSingle() {
        let values = KeyParser.parse("value")
        XCTAssertEqual(values, [.map("value")])
    }

    func testArray() {
        let values = KeyParser.parse("array[]")
        XCTAssertEqual(values, [.map("array"), .array])
    }

    func testMap() {
        let values = KeyParser.parse("array[object]")
        XCTAssertEqual(values, [.map("array"), .map("object")])
    }

    func testArrayMap() {
        let values = KeyParser.parse("array[][object]")
        XCTAssertEqual(values, [.map("array"), .array, .map("object")])
    }

    func testMapArray() {
        let values = KeyParser.parse("array[object][]")
        XCTAssertEqual(values, [.map("array"), .map("object"), .array])
    }
}

