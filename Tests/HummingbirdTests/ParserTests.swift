//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable import HummingbirdCore

struct ParserTests {
    @Test func testCharacter() throws {
        var parser = Parser("TestString")
        #expect(try parser.character() == "T")
        #expect(try parser.character() == "e")
    }

    @Test func testSubstring() throws {
        var parser = Parser("TestString")
        #expect(throws: (any Error).self) { try parser.read(count: 23) }
        #expect(try parser.read(count: 3).string == "Tes")
        #expect(try parser.read(count: 5).string == "tStri")
        #expect(throws: (any Error).self) { try parser.read(count: 3) }
        #expect(throws: Never.self) { try parser.read(count: 2) }
    }

    @Test func testReadCharacter() throws {
        var parser = Parser("TestString")
        #expect(throws: Never.self) { try parser.read("T") }
        #expect(throws: Never.self) { try parser.read("e") }
        #expect(try parser.read("e") == false)
        #expect(try parser.read(Set("hgs")) == true)
    }

    @Test func testReadUntilCharacter() throws {
        var parser = Parser("TestString")
        #expect(try parser.read(until: "S").string == "Test")
        #expect(try parser.read(until: "n").string == "Stri")
        #expect(throws: (any Error).self) { try parser.read(until: "!") }
    }

    @Test func testReadUntilCharacterSet() throws {
        var parser = Parser("TestString")
        #expect(try parser.read(until: Set("Sr")).string == "Test")
        #expect(try parser.read(until: Set("abcdefg")).string == "Strin")
    }

    @Test func testReadUntilString() throws {
        var parser = Parser("<!-- check for -comment end -->")
        #expect(try parser.read(untilString: "-->").string == "<!-- check for -comment end ")
        #expect(try parser.read("-->") == true)
    }

    @Test func testReadWhileCharacter() throws {
        var parser = Parser("122333")
        #expect(parser.read(while: "1") == 1)
        #expect(parser.read(while: "2") == 2)
        #expect(parser.read(while: "3") == 3)
    }

    @Test func testReadWhileCharacterSet() throws {
        var parser = Parser("aabbcdd836de")
        #expect(parser.read(while: Set("abcdef")).string == "aabbcdd")
        #expect(parser.read(while: Set("123456789")).string == "836")
        #expect(parser.read(while: Set("abcdef")).string == "de")
    }

    @Test func testRetreat() throws {
        var parser = Parser("abcdef")
        #expect(throws: (any Error).self) { try parser.retreat() }
        _ = try parser.read(count: 4)
        try parser.retreat(by: 3)
        #expect(try parser.read(count: 4).string == "bcde")
    }

    @Test func testCopy() throws {
        var parser = Parser("abcdef")
        #expect(try parser.read(count: 3).string == "abc")
        var reader2 = parser
        #expect(try parser.read(count: 3).string == "def")
        #expect(try reader2.read(count: 3).string == "def")
    }

    @Test func testSplit() throws {
        var parser = Parser("abc,defgh,ijk")
        let split = parser.split(separator: ",")
        #expect(split.count == 3)
        #expect(split[0].string == "abc")
        #expect(split[1].string == "defgh")
        #expect(split[2].string == "ijk")
    }

    @Test func testPercentDecode() throws {
        let string = "abc,é☺😀併"
        let encoded = string.addingPercentEncoding(forURLComponent: .queryItem)
        var parser = Parser(encoded)
        try! parser.read(until: ",")
        let decoded = try #require(parser.percentDecode())

        #expect(decoded == ",é☺😀併")
    }

    @Test func testValidate() {
        let string = "abc,é☺😀併"
        #expect(Parser([UInt8](string.utf8), validateUTF8: true) != nil)
    }

    @Test func testSequence() {
        let string = "abc,é☺😀併 lorem"
        var string2 = ""
        let parser = Parser(string)
        for c in parser {
            string2 += String(c)
        }
        #expect(string == string2)
    }
}

struct SpanParserTests {
    @available(macOS 26, *)
    @Test func testCharacter() throws {
        let string = "TestString"
        var parser = SpanParser(string)
        #expect(try parser.character() == "T")
        #expect(try parser.character() == "e")
    }

    @available(macOS 26, *)
    @Test func testSubstring() throws {
        let string = "TestString"
        var parser = SpanParser(string)
        #expect(throws: (any Error).self) { try parser.read(count: 23) }
        #expect(try parser.read(count: 3).string == "Tes")
        #expect(try parser.read(count: 5).string == "tStri")
        #expect(throws: (any Error).self) { try parser.read(count: 3) }
        #expect(throws: Never.self) { try parser.read(count: 2) }
    }

    @available(macOS 26, *)
    @Test func testReadCharacter() throws {
        let string = "TestString"
        var parser = SpanParser(string)
        #expect(throws: Never.self) { try parser.read("T") }
        #expect(throws: Never.self) { try parser.read("e") }
        #expect(try parser.read("e") == false)
        #expect(try parser.read(Set("hgs")) == true)
    }

    @available(macOS 26, *)
    @Test func testReadUntilCharacter() throws {
        let string = "TestString"
        var parser = SpanParser(string)
        #expect(try parser.read(until: "S").string == "Test")
        #expect(try parser.read(until: "n").string == "Stri")
        #expect(throws: (any Error).self) { try parser.read(until: "!") }
    }

    @available(macOS 26, *)
    @Test func testReadUntilCharacterSet() throws {
        let string = "TestString"
        var parser = SpanParser(string)
        #expect(try parser.read(until: Set("Sr")).string == "Test")
        #expect(try parser.read(until: Set("abcdefg")).string == "Strin")
    }

    /*@available(macOS 26, *)
    @Test func testReadUntilString() throws {
        var parser = SpanParser("<!-- check for -comment end -->")
        #expect(try parser.read(untilString: "-->").string == "<!-- check for -comment end ")
        #expect(try parser.read("-->") == true)
    }*/

    @available(macOS 26, *)
    @Test func testReadWhileCharacter() throws {
        let string = "122333"
        var parser = SpanParser(string)
        #expect(parser.read(while: "1") == 1)
        #expect(parser.read(while: "2") == 2)
        #expect(parser.read(while: "3") == 3)
    }

    @available(macOS 26, *)
    @Test func testReadWhileCharacterSet() throws {
        let string = "aabbcdd836de"
        var parser = SpanParser(string)
        #expect(parser.read(while: Set("abcdef")).string == "aabbcdd")
        #expect(parser.read(while: Set("123456789")).string == "836")
        #expect(parser.read(while: Set("abcdef")).string == "de")
    }

    @available(macOS 26, *)
    @Test func testRetreat() throws {
        let string = "abcdef"
        var parser = SpanParser(string)
        #expect(throws: (any Error).self) { try parser.retreat() }
        _ = try parser.read(count: 4)
        try parser.retreat(by: 3)
        #expect(try parser.read(count: 4).string == "bcde")
    }

    @available(macOS 26, *)
    @Test func testPerformance() throws {
        let text =
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
        var count = 0
        for _ in 0..<10000 {
            var parser = SpanParser(text)
            while true {
                do {
                    let output = try parser.read(until: "e")
                    count += output.count
                } catch {
                    break
                }
            }
        }
        print(count)
    }
}

extension Character {
    var isAlphaNumeric: Bool {
        isLetter || isNumber
    }
}
