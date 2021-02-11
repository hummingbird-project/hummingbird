import Foundation
import Hummingbird
import XCTest

final class EnvironmentTests: XCTestCase {

    func testInitFromEnvironment() {
        XCTAssertEqual(setenv("TEST_VAR", "testSetFromEnvironment", 1), 0)
        let env = HBEnvironment()
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromEnvironment")
    }

    func testInitFromDictionary() {
        let env = HBEnvironment(values: ["TEST_VAR": "testSetFromDictionary"])
        XCTAssertEqual(env.get("TEST_VAR"), "testSetFromDictionary")
    }

    func testInitFromCodable() {
        let json = #"{"TEST_VAR": "testSetFromCodable"}"#
        var env: HBEnvironment?
        XCTAssertNoThrow(env = try JSONDecoder().decode(HBEnvironment.self, from: Data(json.utf8)))
        XCTAssertEqual(env?.get("TEST_VAR"), "testSetFromCodable")
    }

    func testSet() {
        var env = HBEnvironment()
        env.set("TEST_VAR", value: "testSet")
        XCTAssertEqual(env.get("TEST_VAR"), "testSet")
    }
}
