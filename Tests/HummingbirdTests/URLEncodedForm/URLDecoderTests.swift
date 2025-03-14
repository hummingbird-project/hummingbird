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

@testable import Hummingbird

final class URLDecodedFormDecoderTests: XCTestCase {
    func testForm<Input: Decodable & Equatable>(
        _ value: Input,
        query: String,
        decoder: URLEncodedFormDecoder = .init(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            let value2 = try decoder.decode(Input.self, from: query)
            XCTAssertEqual(value, value2, file: file, line: line)
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }

    func testSimpleStructureDecode() {
        struct Test: Codable, Equatable {
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
        self.testForm(test, query: "b=true&i=34&i8=23&i16=9&i32=-6872&i64=23&u=0&u8=255&u16=7673&u32=88222&u64=234&f=-1.1&d=8")
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
        let test = Test(
            b: [true, false],
            i: [34],
            i8: [23],
            i16: [9],
            i32: [-6872],
            i64: [23],
            u: [0],
            u8: [255],
            u16: [7673],
            u32: [88222],
            u64: [234],
            f: [-1.1],
            d: [8]
        )
        self.testForm(
            test,
            query: "b[]=true&b[]=false&i[]=34&i8[]=23&i16[]=9&i32[]=-6872&i64[]=23&u[]=0&u8[]=255&u16[]=7673&u32[]=88222&u64[]=234&f[]=-1.1&d[]=8"
        )
    }

    func testArraysWithIndices() {
        struct Test: Codable, Equatable {
            let arr: [Int]
        }
        let test = Test(arr: [12, 45, 54, 55, -5, 5])
        self.testForm(test, query: "arr[0]=12&arr[1]=45&arr[2]=54&arr[3]=55&arr[4]=-5&arr[5]=5")

        let test2 = Test(arr: [12, 45, 54, 55, -5, 5, 9, 33, 0, 9, 4, 33])
        let query = """
            arr[0]=12\
            &arr[1]=45\
            &arr[2]=54\
            &arr[3]=55\
            &arr[4]=-5\
            &arr[5]=5\
            &arr[6]=9\
            &arr[7]=33\
            &arr[8]=0\
            &arr[9]=9\
            &arr[10]=4\
            &arr[11]=33
            """
        self.testForm(test2, query: query)
    }

    func testArrayWithIndicesThrows() {
        struct Test: Codable, Equatable {
            let arr: [Int]
        }
        let decoder = URLEncodedFormDecoder()
        // incorrect indices
        let query = "arr[0]=2&arr[2]=4"
        XCTAssertThrowsError(try decoder.decode(Test.self, from: query)) { error in
            guard let error = try? XCTUnwrap(error as? URLEncodedFormError) else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.code, .invalidArrayIndex)
            XCTAssertEqual(error.value, "arr")
        }
    }

    func testStringSpecialCharactersDecode() {
        struct Test: Codable, Equatable {
            let a: String
        }
        let test = Test(a: "adam+!@£$%^&*()_=")
        self.testForm(test, query: "a=adam%2B%21%40%C2%A3%24%25%5E%26%2A%28%29_%3D")
    }

    func testContainingStructureDecode() {
        struct Test: Codable, Equatable {
            let a: Int8
            let b: String
        }
        struct Test2: Codable, Equatable {
            let t: Test
        }
        let test = Test2(t: Test(a: 42, b: "Life"))
        self.testForm(test, query: "t[a]=42&t[b]=Life")
    }

    func testEnumDecode() {
        struct Test: Codable, Equatable {
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

    func testArrayDecode() {
        struct Test: Codable, Equatable {
            let a: [Int16]
        }
        let test = Test(a: [9, 8, 7, 6])
        self.testForm(test, query: "a[]=9&a[]=8&a[]=7&a[]=6")
    }

    func testDictionaryDecode() {
        struct Test: Codable, Equatable {
            let a: [String: Int]
        }
        let test = Test(a: ["one": 1, "two": 2, "three": 3])
        self.testForm(test, query: "a[one]=1&a[three]=3&a[two]=2")
    }

    func testDateDecode() {
        struct Test: Codable, Equatable {
            let d: Date
        }
        let test = Test(d: Date(timeIntervalSinceReferenceDate: 2_387_643))
        self.testForm(test, query: "d=2387643.0")
        self.testForm(test, query: "d=980694843000", decoder: .init(dateDecodingStrategy: .millisecondsSince1970))
        self.testForm(test, query: "d=980694843", decoder: .init(dateDecodingStrategy: .secondsSince1970))
        self.testForm(test, query: "d=2001-01-28T15%3A14%3A03Z", decoder: .init(dateDecodingStrategy: .iso8601))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.testForm(test, query: "d=2001-01-28T15%3A14%3A03.000Z", decoder: .init(dateDecodingStrategy: .formatted(dateFormatter)))
    }

    func testDataBlobDecode() {
        struct Test: Codable, Equatable {
            let a: Data
        }
        let data = Data("Testing".utf8)
        let test = Test(a: data)
        self.testForm(test, query: "a=VGVzdGluZw%3D%3D")
    }

    func testIndexOutOfRange() {
        struct Test: Codable, Equatable {
            let a: ClosedRange<Int>
        }
        XCTAssertThrowsError(try URLEncodedFormDecoder().decode(Test.self, from: "a[]=4")) { error in
            if case DecodingError.valueNotFound = error {
            } else {
                XCTFail("\(error)")
            }
        }
    }

    func testNestedKeyDecode() {
        struct Test: Decodable, Equatable {
            let forename: String
            let surname: String
            let age: Int

            init(forename: String, surname: String, age: Int) {
                self.forename = forename
                self.surname = surname
                self.age = age
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let nameContainer = try container.nestedContainer(keyedBy: NameCodingKeys.self, forKey: .name)
                self.forename = try nameContainer.decode(String.self, forKey: .forename)
                self.surname = try nameContainer.decode(String.self, forKey: .surname)
                self.age = try container.decode(Int.self, forKey: .age)
            }

            private enum CodingKeys: String, CodingKey {
                case name
                case age
            }

            private enum NameCodingKeys: String, CodingKey {
                case forename = "first"
                case surname = "second"
            }
        }
        let test = Test(forename: "John", surname: "Smith", age: 23)
        self.testForm(test, query: "name[first]=John&name[second]=Smith&age=23")
    }

    func testOptional() {
        struct Test: Decodable, Equatable {
            let name: String
            let age: Int?
        }
        let test = Test(name: "John", age: nil)
        self.testForm(test, query: "name=John")
    }

    func testURLDecode() throws {
        struct URLForm: Decodable, Equatable {
            let site: URL
        }

        let test = URLForm(site: URL(string: "https://hummingbird.codes")!)

        self.testForm(test, query: "site=https://hummingbird.codes")
    }

    func testDecodingEmptyArrayAndMap() throws {
        struct ArrayDecoding: Decodable, Equatable {
            let array: [Int]
            let map: [String: Int]
            let a: Int
        }
        self.testForm(ArrayDecoding(array: [], map: [:], a: 3), query: "a=3")
    }

    func testDecodeErrors() throws {
        struct Input1: Decodable {}
        XCTAssertThrowsError(try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField=2")) { error in
            guard let error = try? XCTUnwrap(error as? URLEncodedFormError) else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.code, .duplicateKeys)
            XCTAssertEqual(error.value, "someField")
        }
        XCTAssertThrowsError(try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField[]=2")) { error in
            guard let error = try? XCTUnwrap(error as? URLEncodedFormError) else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.code, .addingToInvalidType)
            XCTAssertEqual(error.value, "someField")
        }
        XCTAssertThrowsError(try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField[test]=2")) { error in
            guard let error = try? XCTUnwrap(error as? URLEncodedFormError) else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.code, .addingToInvalidType)
            XCTAssertEqual(error.value, "someField")
        }
    }
}
