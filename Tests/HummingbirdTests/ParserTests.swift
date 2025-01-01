//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest

@testable import HummingbirdCore

final class ParserTests: XCTestCase {
    func testCharacter() {
        var parser = Parser("TestString")
        XCTAssertEqual(try parser.character(), "T")
        XCTAssertEqual(try parser.character(), "e")
    }

    func testSubstring() {
        var parser = Parser("TestString")
        XCTAssertThrowsError(try parser.read(count: 23))
        XCTAssertEqual(try parser.read(count: 3).string, "Tes")
        XCTAssertEqual(try parser.read(count: 5).string, "tStri")
        XCTAssertThrowsError(try parser.read(count: 3))
        XCTAssertNoThrow(try parser.read(count: 2))
    }

    func testReadCharacter() {
        var parser = Parser("TestString")
        XCTAssertNoThrow(try parser.read("T"))
        XCTAssertNoThrow(try parser.read("e"))
        XCTAssertEqual(try parser.read("e"), false)
        XCTAssertEqual(try parser.read(Set("hgs")), true)
    }

    func testReadUntilCharacter() throws {
        var parser = Parser("TestString")
        XCTAssertEqual(try parser.read(until: "S").string, "Test")
        XCTAssertEqual(try parser.read(until: "n").string, "Stri")
        XCTAssertThrowsError(try parser.read(until: "!"))
    }

    func testReadUntilCharacterSet() throws {
        var parser = Parser("TestString")
        XCTAssertEqual(try parser.read(until: Set("Sr")).string, "Test")
        XCTAssertEqual(try parser.read(until: Set("abcdefg")).string, "Strin")
    }

    func testReadUntilString() throws {
        var parser = Parser("<!-- check for -comment end -->")
        XCTAssertEqual(try parser.read(untilString: "-->").string, "<!-- check for -comment end ")
        XCTAssertTrue(try parser.read("-->"))
    }

    func testReadWhileCharacter() throws {
        var parser = Parser("122333")
        XCTAssertEqual(parser.read(while: "1"), 1)
        XCTAssertEqual(parser.read(while: "2"), 2)
        XCTAssertEqual(parser.read(while: "3"), 3)
    }

    func testReadWhileCharacterSet() throws {
        var parser = Parser("aabbcdd836de")
        XCTAssertEqual(parser.read(while: Set("abcdef")).string, "aabbcdd")
        XCTAssertEqual(parser.read(while: Set("123456789")).string, "836")
        XCTAssertEqual(parser.read(while: Set("abcdef")).string, "de")
    }

    func testRetreat() throws {
        var parser = Parser("abcdef")
        XCTAssertThrowsError(try parser.retreat())
        _ = try parser.read(count: 4)
        try parser.retreat(by: 3)
        XCTAssertEqual(try parser.read(count: 4).string, "bcde")
    }

    func testCopy() throws {
        var parser = Parser("abcdef")
        XCTAssertEqual(try parser.read(count: 3).string, "abc")
        var reader2 = parser
        XCTAssertEqual(try parser.read(count: 3).string, "def")
        XCTAssertEqual(try reader2.read(count: 3).string, "def")
    }

    func testSplit() throws {
        var parser = Parser("abc,defgh,ijk")
        let split = parser.split(separator: ",")
        XCTAssertEqual(split.count, 3)
        XCTAssertEqual(split[0].string, "abc")
        XCTAssertEqual(split[1].string, "defgh")
        XCTAssertEqual(split[2].string, "ijk")
    }

    func testPercentDecode() throws {
        let string = "abc,é☺😀併"
        let encoded = string.addingPercentEncoding(forURLComponent: .queryItem)
        var parser = Parser(encoded)
        try! parser.read(until: ",")
        let decoded = try XCTUnwrap(parser.percentDecode())

        XCTAssertEqual(decoded, ",é☺😀併")
    }

    func testValidate() {
        let string = "abc,é☺😀併"
        XCTAssertNotNil(Parser([UInt8](string.utf8), validateUTF8: true))
    }

    func testSequence() {
        let string = "abc,é☺😀併 lorem"
        var string2 = ""
        let parser = Parser(string)
        for c in parser {
            string2 += String(c)
        }
        XCTAssertEqual(string, string2)
    }
}

extension Character {
    var isAlphaNumeric: Bool {
        isLetter || isNumber
    }
}
