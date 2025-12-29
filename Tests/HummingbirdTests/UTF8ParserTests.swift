//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if compiler(>=6.2)

import Testing

@testable import HummingbirdCore

struct UTF8ParserTests {
    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testCharacter() throws {
        let utf8Span = "TestString".utf8Span
        var parser = UTF8Parser(utf8Span)
        #expect(try parser.character() == "T")
        #expect(try parser.character() == "e")
    }

    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testSubstring() throws {
        let utf8Span = "TestString".utf8Span
        var parser = UTF8Parser(utf8Span)
        #expect(throws: (any Error).self) { _ = try parser.read(count: 23) }
        var span = try parser.read(count: 3)
        #expect(String(copying: span) == "Tes")
        span = try parser.read(count: 5)
        #expect(String(copying: span) == "tStri")
        #expect(throws: (any Error).self) { _ = try parser.read(count: 3) }
        #expect(throws: Never.self) { try _ = parser.read(count: 2) }
    }

    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testReadCharacter() throws {
        let utf8Span = "TestString".utf8Span
        var parser = UTF8Parser(utf8Span)
        #expect(throws: Never.self) { try parser.read("T") }
        #expect(throws: Never.self) { try parser.read("e") }
        #expect(try parser.read("e") == false)
        #expect(try parser.read(Set("hgs")) == true)
    }

    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testReadUntilCharacter() throws {
        let utf8Span = "TestString".utf8Span
        var parser = UTF8Parser(utf8Span)
        #expect(try String(copying: parser.read(until: "S")) == "Test")
        #expect(try String(copying: parser.read(until: "n")) == "Stri")
        #expect(throws: (any Error).self) { try parser.read(until: "!") }
    }

    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testReadUntilCharacterSet() throws {
        var parser = Parser("TestString")
        #expect(try parser.read(until: Set("Sr")).string == "Test")
        #expect(try parser.read(until: Set("abcdefg")).string == "Strin")
    }

    @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
    @Test func testReadUntilString() throws {
        var parser = Parser("<!-- check for -comment end -->")
        #expect(try parser.read(untilString: "-->").string == "<!-- check for -comment end ")
        #expect(try parser.read("-->") == true)
    }
    /*
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testReadWhileCharacter() throws {
                 var parser = Parser("122333")
                 #expect(parser.read(while: "1") == 1)
                 #expect(parser.read(while: "2") == 2)
                 #expect(parser.read(while: "3") == 3)
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testReadWhileCharacterSet() throws {
                 var parser = Parser("aabbcdd836de")
                 #expect(parser.read(while: Set("abcdef")).string == "aabbcdd")
                 #expect(parser.read(while: Set("123456789")).string == "836")
                 #expect(parser.read(while: Set("abcdef")).string == "de")
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testRetreat() throws {
                 var parser = Parser("abcdefgh")
                 #expect(throws: (any Error).self) { try parser.retreat() }
                 _ = try parser.read(count: 4)
                 try parser.retreat()
                 #expect(try parser.read(count: 4).string == "defg")
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testCopy() throws {
                 var parser = Parser("abcdef")
                 #expect(try parser.read(count: 3).string == "abc")
                 var reader2 = parser
                 #expect(try parser.read(count: 3).string == "def")
                 #expect(try reader2.read(count: 3).string == "def")
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testSplit() throws {
                 var parser = Parser("abc,defgh,ijk")
                 let split = parser.split(separator: ",")
                 #expect(split.count == 3)
                 #expect(split[0].string == "abc")
                 #expect(split[1].string == "defgh")
                 #expect(split[2].string == "ijk")
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testPercentDecode() throws {
                 let string = "abc,é☺😀併"
                 let encoded = string.addingPercentEncoding(forURLComponent: .queryItem)
                 var parser = Parser(encoded)
                 try! parser.read(until: ",")
                 let decoded = try #require(parser.percentDecode())
    
                 #expect(decoded == ",é☺😀併")
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testValidate() {
                 let string = "abc,é☺😀併"
                 #expect(Parser([UInt8](string.utf8), validateUTF8: true) != nil)
             }
    
             @available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
             @Test func testSequence() {
                 let string = "abc,é☺😀併 lorem"
                 var string2 = ""
                 let parser = Parser(string)
                 for c in parser {
                     string2 += String(c)
                 }
                 #expect(string == string2)
             }
         */
}

#endif
