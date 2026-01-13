//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Testing

@testable import Hummingbird

extension URLEncodedFormTests {
    struct NodeTests {
        static func expectEncodedEqual(
            _ lhs: String,
            _ rhs: String,
            sourceLocation: SourceLocation
        ) {
            let lhs = lhs.split(separator: "&")
                .sorted { $0 < $1 }
                .joined(separator: "&")
            let rhs = rhs.split(separator: "&")
                .sorted { $0 < $1 }
                .joined(separator: "&")
            #expect(lhs == rhs, sourceLocation: sourceLocation)
        }

        func testDecodeEncode(
            _ string: String,
            encoded: URLEncodedFormNode,
            fileID: String = #fileID,
            filePath: String = #filePath,
            line: Int = #line,
            column: Int = #column
        ) {
            #expect(throws: Never.self) {
                let formData = try URLEncodedFormNode(from: string)
                #expect(formData == encoded, sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column))
                Self.expectEncodedEqual(
                    formData.description,
                    string,
                    sourceLocation: .init(fileID: fileID, filePath: filePath, line: line, column: column)
                )
            }
        }

        @Test func testKeyParserSingle() {
            let values = KeyParser.parse("value")
            #expect(values == [.map("value")])
        }

        @Test func testKeyParserArray() {
            let values = KeyParser.parse("array[]")
            #expect(values == [.map("array"), .array])
        }

        @Test func testKeyParserArrayWithIndices() {
            let values = KeyParser.parse("array[0]")
            #expect(values == [.map("array"), .arrayWithIndices(0)])
        }

        @Test func testKeyParserMap() {
            let values = KeyParser.parse("array[object]")
            #expect(values == [.map("array"), .map("object")])
        }

        @Test func testKeyParserArrayMap() {
            let values = KeyParser.parse("array[][object]")
            #expect(values == [.map("array"), .array, .map("object")])
        }

        @Test func testKeyParserMapArray() {
            let values = KeyParser.parse("array[object][]")
            #expect(values == [.map("array"), .map("object"), .array])
        }

        @Test func testSimple() {
            let values = "one=1&two=2&three=3"
            let encoded: URLEncodedFormNode = ["one": "1", "two": "2", "three": "3"]
            self.testDecodeEncode(values, encoded: encoded)
        }

        @Test func testArray() {
            let values = "array[]=1&array[]=2&array[]=3&array[]=6"
            let encoded: URLEncodedFormNode = ["array": ["1", "2", "3", "6"]]
            self.testDecodeEncode(values, encoded: encoded)
        }

        @Test func testMap() {
            let values = "map[one]=1&map[two]=2&map[three]=3&map[six]=6"
            let encoded: URLEncodedFormNode = ["map": ["one": "1", "two": "2", "three": "3", "six": "6"]]
            self.testDecodeEncode(values, encoded: encoded)
        }

        @Test func testMapArray() {
            let values = "map[numbers][]=1&map[numbers][]=2"
            let encoded: URLEncodedFormNode = ["map": ["numbers": ["1", "2"]]]
            self.testDecodeEncode(values, encoded: encoded)
        }

        @Test func testMapMap() {
            let values = "map[numbers][one]=1&map[numbers][two]=2"
            let encoded: URLEncodedFormNode = ["map": ["numbers": ["one": "1", "two": "2"]]]
            self.testDecodeEncode(values, encoded: encoded)
        }

        @Test func testPlusSign() {
            let values = "name=John+Smith"
            let encoded: URLEncodedFormNode = ["name": "John Smith"]
            #expect(throws: Never.self) {
                let formData = try URLEncodedFormNode(from: values)
                // only compare URLEncodedFormNode. Once encoded as string space is converted to %20
                #expect(formData == encoded)
            }
        }
    }
}

extension URLEncodedFormNode: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .leaf(.init(value))
    }
}
extension URLEncodedFormNode: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = URLEncodedFormNode

    public init(dictionaryLiteral elements: (String, URLEncodedFormNode)...) {
        self = .map(.init(values: .init(elements) { first, _ in first }))
    }

}
extension URLEncodedFormNode: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: URLEncodedFormNode...) {
        self = .array(.init(values: .init(elements)))
    }
}
