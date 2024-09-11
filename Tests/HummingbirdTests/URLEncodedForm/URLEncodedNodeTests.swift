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

@testable import Hummingbird
import XCTest

final class URLEncodedFormNodeTests: XCTestCase {
    static func XCTAssertEncodedEqual(_ lhs: String, _ rhs: String) {
        let lhs = lhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        let rhs = rhs.split(separator: "&")
            .sorted { $0 < $1 }
            .joined(separator: "&")
        XCTAssertEqual(lhs, rhs)
    }

    func testDecodeEncode(_ string: String, encoded: URLEncodedFormNode) {
        do {
            let formData = try URLEncodedFormNode(from: string)
            XCTAssertEqual(formData, encoded)
            Self.XCTAssertEncodedEqual(formData.description, string)
        } catch {
            XCTFail("\(error)")
        }
    }

    func testKeyParserSingle() {
        let values = KeyParser.parse("value")
        XCTAssertEqual(values, [.map("value")])
    }

    func testKeyParserArray() {
        let values = KeyParser.parse("array[]")
        XCTAssertEqual(values, [.map("array"), .array])
    }

    func testKeyParserArrayWithIndices() {
        let values = KeyParser.parse("array[0]")
        XCTAssertEqual(values, [.map("array"), .arrayWithIndices(0)])
    }

    func testKeyParserMap() {
        let values = KeyParser.parse("array[object]")
        XCTAssertEqual(values, [.map("array"), .map("object")])
    }

    func testKeyParserArrayMap() {
        let values = KeyParser.parse("array[][object]")
        XCTAssertEqual(values, [.map("array"), .array, .map("object")])
    }

    func testKeyParserMapArray() {
        let values = KeyParser.parse("array[object][]")
        XCTAssertEqual(values, [.map("array"), .map("object"), .array])
    }

    func testSimple() {
        let values = "one=1&two=2&three=3"
        let encoded: URLEncodedFormNode = ["one": "1", "two": "2", "three": "3"]
        self.testDecodeEncode(values, encoded: encoded)
    }

    func testArray() {
        let values = "array[]=1&array[]=2&array[]=3&array[]=6"
        let encoded: URLEncodedFormNode = ["array": ["1", "2", "3", "6"]]
        self.testDecodeEncode(values, encoded: encoded)
    }

    func testMap() {
        let values = "map[one]=1&map[two]=2&map[three]=3&map[six]=6"
        let encoded: URLEncodedFormNode = ["map": ["one": "1", "two": "2", "three": "3", "six": "6"]]
        self.testDecodeEncode(values, encoded: encoded)
    }

    func testMapArray() {
        let values = "map[numbers][]=1&map[numbers][]=2"
        let encoded: URLEncodedFormNode = ["map": ["numbers": ["1", "2"]]]
        self.testDecodeEncode(values, encoded: encoded)
    }

    func testMapMap() {
        let values = "map[numbers][one]=1&map[numbers][two]=2"
        let encoded: URLEncodedFormNode = ["map": ["numbers": ["one": "1", "two": "2"]]]
        self.testDecodeEncode(values, encoded: encoded)
    }

    func testPlusSign() {
        let values = "name=John+Smith"
        let encoded: URLEncodedFormNode = ["name": "John Smith"]
        do {
            let formData = try URLEncodedFormNode(from: values)
            // only compare URLEncodedFormNode. Once encoded as string space is converted to %20
            XCTAssertEqual(formData, encoded)
        } catch {
            XCTFail("\(error)")
        }
    }
}

extension URLEncodedFormNode: ExpressibleByStringLiteral {}
extension URLEncodedFormNode: ExpressibleByDictionaryLiteral {}
extension URLEncodedFormNode: ExpressibleByArrayLiteral {}

extension URLEncodedFormNode {
    public typealias Key = String
    public typealias Value = URLEncodedFormNode

    public init(stringLiteral value: String) {
        self = .leaf(.init(value))
    }

    public init(dictionaryLiteral elements: (String, URLEncodedFormNode)...) {
        self = .map(.init(values: .init(elements) { first, _ in first }))
    }

    public init(arrayLiteral elements: URLEncodedFormNode...) {
        self = .array(.init(values: .init(elements)))
    }
}
