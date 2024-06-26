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

import Hummingbird
import XCTest

class URLEncodedFormEncoderTests: XCTestCase {
    static func XCTAssertEncodedEqual(_ lhs: String, _ rhs: String) {
        let lhs = lhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        let rhs = rhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        XCTAssertEqual(lhs, rhs)
    }

    func testForm(_ value: some Encodable, query: String, encoder: URLEncodedFormEncoder = .init()) {
        do {
            let query2 = try encoder.encode(value)
            Self.XCTAssertEncodedEqual(query2, query)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testSimpleStructureEncode() {
        struct Test: Codable {
            let a: String
            let b: Int

            private enum CodingKeys: String, CodingKey {
                case a = "A"
                case b = "B"
            }
        }
        let test = Test(a: "Testing", b: 42)
        self.testForm(test, query: "A=Testing&B=42")
    }

    func testNumbers() {
        struct Test: Codable, Equatable {
            let b: Bool
            let i: Int
            let i8: Int8
            let i16: Int16
            let i32: Int32
            let i64: Int64
            let u: UInt
            let u8: UInt8
            let u16: UInt16
            let u32: UInt32
            let u64: UInt64
            let f: Float
            let d: Double
        }
        let test = Test(b: true, i: 34, i8: 23, i16: 9, i32: -6872, i64: 23, u: 0, u8: 255, u16: 7673, u32: 88222, u64: 234, f: -1.1, d: 8)
        self.testForm(test, query: "b=true&i=34&i8=23&i16=9&i32=-6872&i64=23&u=0&u8=255&u16=7673&u32=88222&u64=234&f=-1.1&d=8.0")
    }

    func testNumberArrays() {
        struct Test: Codable, Equatable {
            let b: [Bool]
            let i: [Int]
            let i8: [Int8]
            let i16: [Int16]
            let i32: [Int32]
            let i64: [Int64]
            let u: [UInt]
            let u8: [UInt8]
            let u16: [UInt16]
            let u32: [UInt32]
            let u64: [UInt64]
            let f: [Float]
            let d: [Double]
        }
        let test = Test(b: [true], i: [34], i8: [23], i16: [9], i32: [-6872], i64: [23], u: [0], u8: [255], u16: [7673], u32: [88222], u64: [234], f: [-1.1], d: [8])
        self.testForm(test, query: "b[]=true&i[]=34&i8[]=23&i16[]=9&i32[]=-6872&i64[]=23&u[]=0&u8[]=255&u16[]=7673&u32[]=88222&u64[]=234&f[]=-1.1&d[]=8.0")
    }

    func testStringSpecialCharactersEncode() {
        struct Test: Codable {
            let a: String
        }
        let test = Test(a: "adam+!@£$%^&*()_=")
        self.testForm(test, query: "a=adam%2B%21%40%C2%A3%24%25%5E%26%2A%28%29_%3D")
    }

    func testContainingStructureEncode() {
        struct Test: Codable {
            let a: Int
            let b: String
        }
        struct Test2: Codable {
            let t: Test
        }
        let test = Test2(t: Test(a: 42, b: "Life"))
        self.testForm(test, query: "t[a]=42&t[b]=Life")
    }

    func testEnumEncode() {
        struct Test: Codable {
            enum TestEnum: String, Codable {
                case first
                case second
            }

            let a: TestEnum
        }
        let test = Test(a: .second)
        // NB enum names don't change to rawValue (not sure how to fix)
        self.testForm(test, query: "a=second")
    }

    func testArrayEncode() {
        struct Test: Codable {
            let a: [Int]
        }
        let test = Test(a: [9, 8, 7, 6])
        self.testForm(test, query: "a[]=9&a[]=8&a[]=7&a[]=6")
    }

    func testDictionaryEncode() {
        struct Test: Codable {
            let a: [String: Int]
        }
        let test = Test(a: ["one": 1, "two": 2, "three": 3])
        self.testForm(test, query: "a[one]=1&a[three]=3&a[two]=2")
    }

    func testDateEncode() {
        struct Test: Codable {
            let d: Date
        }
        let test = Test(d: Date(timeIntervalSinceReferenceDate: 2_387_643))
        self.testForm(test, query: "d=2387643.0")
        self.testForm(test, query: "d=980694843000.0", encoder: .init(dateEncodingStrategy: .millisecondsSince1970))
        self.testForm(test, query: "d=980694843.0", encoder: .init(dateEncodingStrategy: .secondsSince1970))
        self.testForm(test, query: "d=2001-01-28T15%3A14%3A03Z", encoder: .init(dateEncodingStrategy: .iso8601))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.testForm(test, query: "d=2001-01-28T15%3A14%3A03.000Z", encoder: .init(dateEncodingStrategy: .formatted(dateFormatter)))
    }

    func testDataBlobEncode() {
        struct Test: Codable {
            let a: Data
        }
        let data = Data("Testing".utf8)
        let test = Test(a: data)
        self.testForm(test, query: "a=VGVzdGluZw%3D%3D")
    }

    func testOptional() {
        struct Test: Encodable, Equatable {
            let name: String
            let age: Int?
        }
        let test = Test(name: "John", age: nil)
        self.testForm(test, query: "name=John")
    }
}
