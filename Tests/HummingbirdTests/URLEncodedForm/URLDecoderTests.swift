//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Testing

@testable import Hummingbird

extension URLEncodedFormTests {
    struct DecoderTests {
        func testForm<Input: Decodable & Equatable>(
            _ value: Input,
            query: String,
            decoder: URLEncodedFormDecoder = .init(),
            fileID: String = #fileID,
            filePath: String = #filePath,
            line: Int = #line,
            column: Int = #column
        ) {
            do {
                let value2 = try decoder.decode(Input.self, from: query)
                #expect(value == value2, sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column))
            } catch {
                Issue.record("\(error)", sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column))
            }
        }

        @Test func testSimpleStructureDecode() {
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

        @Test func testNumbers() {
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

        @Test func testNumberArrays() {
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

        @Test func testArraysWithIndices() {
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

        @Test func testArrayWithIndicesThrows() {
            struct Test: Codable, Equatable {
                let arr: [Int]
            }
            let decoder = URLEncodedFormDecoder()
            // incorrect indices
            let query = "arr[0]=2&arr[2]=4"
            #expect(throws: URLEncodedFormError(code: .invalidArrayIndex, value: "arr[2]")) { try decoder.decode(Test.self, from: query) }
        }

        @Test func testOptionalArrays() {
            struct Test: Codable, Equatable {
                let arr: [Int]?
            }

            let test = Test(arr: [1, 2, 3, 4])
            self.testForm(test, query: "arr[]=1&arr[]=2&arr[]=3&arr[]=4")

            let test2 = Test(arr: nil)
            self.testForm(test2, query: "")
        }

        @Test func testStringSpecialCharactersDecode() {
            struct Test: Codable, Equatable {
                let a: String
            }
            let test = Test(a: "adam+!@£$%^&*()_=")
            self.testForm(test, query: "a=adam%2B%21%40%C2%A3%24%25%5E%26%2A%28%29_%3D")
        }

        @Test func testContainingStructureDecode() {
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

        @Test func testEnumDecode() {
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

        @Test func testArrayDecode() {
            struct Test: Codable, Equatable {
                let a: [Int16]
            }
            let test = Test(a: [9, 8, 7, 6])
            self.testForm(test, query: "a[]=9&a[]=8&a[]=7&a[]=6")
        }

        @Test func testDictionaryDecode() {
            struct Test: Codable, Equatable {
                let a: [String: Int]
            }
            let test = Test(a: ["one": 1, "two": 2, "three": 3])
            self.testForm(test, query: "a[one]=1&a[three]=3&a[two]=2")
        }

        @Test func testOptionalMaps() {
            struct Test: Codable, Equatable {
                let map: [String: Int]?
            }

            let test = Test(map: ["one": 1, "two": 2, "three": 3])
            self.testForm(test, query: "map[one]=1&map[two]=2&map[three]=3")

            let test2 = Test(map: nil)
            self.testForm(test2, query: "")
        }

        @Test func testDateDecode() {
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

        @Test func testDataBlobDecode() {
            struct Test: Codable, Equatable {
                let a: Data
            }
            let data = Data("Testing".utf8)
            let test = Test(a: data)
            self.testForm(test, query: "a=VGVzdGluZw%3D%3D")
        }

        @Test func testIndexOutOfRange() {
            struct Test: Codable, Equatable {
                let a: ClosedRange<Int>
            }
            #expect(throws: DecodingError.self) { try URLEncodedFormDecoder().decode(Test.self, from: "a[]=4") }
        }

        @Test func testNestedKeyDecode() {
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

        @Test func testOptional() {
            struct Test: Decodable, Equatable {
                let name: String
                let age: Int?
            }
            let test = Test(name: "John", age: nil)
            self.testForm(test, query: "name=John")
        }

        @Test func testURLDecode() throws {
            struct URLForm: Decodable, Equatable {
                let site: URL
            }

            let test = URLForm(site: URL(string: "https://hummingbird.codes")!)

            self.testForm(test, query: "site=https://hummingbird.codes")
        }

        @Test func testDecodingEmptyArrayAndMap() throws {
            struct ArrayDecoding: Decodable, Equatable {
                let array: [Int]
                let map: [String: Int]
                let a: Int
            }
            self.testForm(ArrayDecoding(array: [], map: [:], a: 3), query: "a=3")
        }

        @Test func testParsingErrors() throws {
            struct Input1: Decodable {}
            #expect(throws: URLEncodedFormError(code: .duplicateKeys, value: "someField")) {
                try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField=2")
            }
            #expect(throws: URLEncodedFormError(code: .duplicateKeys, value: "someField")) {
                try URLEncodedFormDecoder().decode(Input1.self, from: "someField[]=1&someField=2")
            }
            #expect(throws: URLEncodedFormError(code: .addingToInvalidType, value: "someField")) {
                try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField[]=2")
            }
            #expect(throws: URLEncodedFormError(code: .addingToInvalidType, value: "someField")) {
                try URLEncodedFormDecoder().decode(Input1.self, from: "someField=1&someField[test]=2")
            }
            #expect(throws: URLEncodedFormError(code: .corruptKeyValue, value: "someField[")) {
                try URLEncodedFormDecoder().decode(Input1.self, from: "someField[=2")
            }
        }
    }
}
