//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Error thrown from parsing URLEncoded forms
public struct URLEncodedFormError: Error, CustomStringConvertible, Equatable {
    public struct Code: Sendable, Equatable {
        fileprivate enum Internal: Equatable {
            case duplicateKeys
            case addingToInvalidType
            case failedToPercentDecode
            case corruptKeyValue
            case notSupported
            case invalidArrayIndex
            case unexpectedError
        }
        fileprivate let value: Internal

        /// encoded form has duplicate keys in it
        public static var duplicateKeys: Self { .init(value: .duplicateKeys) }
        /// trying to add an array or dictionary value to something isnt an array of dictionary
        public static var addingToInvalidType: Self { .init(value: .addingToInvalidType) }
        /// failed to percent decode key or value
        public static var failedToPercentDecode: Self { .init(value: .failedToPercentDecode) }
        /// corrupt dictionary key in form data
        public static var corruptKeyValue: Self { .init(value: .corruptKeyValue) }
        /// Form structure not supported eg arrays of arrays
        public static var notSupported: Self { .init(value: .notSupported) }
        /// Array includes an invalid array index
        public static var invalidArrayIndex: Self { .init(value: .invalidArrayIndex) }
        /// Unexpected errpr
        public static var unexpectedError: Self { .init(value: .unexpectedError) }
    }

    public let code: Code
    public let value: String

    package init(code: Code, value: String) {
        self.code = code
        self.value = value
    }

    init(code: Code, value: Substring) {
        self.code = code
        self.value = .init(value)
    }
}

extension URLEncodedFormError {
    public var description: String {
        switch self.code.value {
        case .duplicateKeys: "Found duplicate keys with name '\(self.value)'"
        case .addingToInvalidType: "Adding array or dictionary value to non array or dictionary value '\(self.value)'"
        case .failedToPercentDecode: "Failed to percent decode '\(self.value)'"
        case .corruptKeyValue: "Parsing dictionary key value failed '\(self.value)'"
        case .notSupported: "URLEncoded form structure not supported '\(self.value)'"
        case .invalidArrayIndex: "Invalid array index '\(self.value)'"
        case .unexpectedError:
            "Unexpected error with '\(self.value)' please add an issue at https://github.com/hummingbird-project/hummingbird/issues"
        }
    }
}
/// Internal representation of URL encoded form data used by both encode and decode
enum URLEncodedFormNode: CustomStringConvertible, Equatable {
    /// holds a value
    case leaf(NodeValue?)
    /// holds a map of strings to nodes
    case map(Map)
    /// holds an array of nodes
    case array(Array)
    // empty node
    case empty

    /// Initialize node from URL encoded form data
    /// - Parameter string: URL encoded form data
    init(from string: String) throws {
        self = try Self.decode(string)
    }

    var description: String {
        self.encode("")
    }

    /// Create `URLEncodedFormNode` from URL encoded form data
    /// - Parameter string: URL encoded form data
    private static func decode(_ string: String) throws -> URLEncodedFormNode {
        let split = string.splitSequence(separator: "&")
        let node = Self.map(.init())
        for element in split {
            if let equals = element.firstIndex(of: "=") {
                let before = element[..<equals].removingURLPercentEncoding()
                let afterEquals = element.index(after: equals)
                let after = String(element[afterEquals...].replacing("+", with: " "))
                guard let key = before else { throw URLEncodedFormError(code: .failedToPercentDecode, value: element[..<equals]) }

                guard let keys = KeyParser.parse(key) else { throw URLEncodedFormError(code: .corruptKeyValue, value: key) }
                guard let value = NodeValue(percentEncoded: after) else {
                    throw URLEncodedFormError(code: .failedToPercentDecode, value: after)
                }

                try node.addValue(keys: keys[...], value: value, key: key)
            }
        }
        return node
    }

    /// Add URL encoded string to node
    /// - Parameters:
    ///   - keys: Array of key parser types (array or map)
    ///   - value: value to add to leaf node
    private func addValue(keys: ArraySlice<KeyParser.KeyType>, value: NodeValue, key: String) throws {
        /// function for create `URLEncodedFormNode` from `KeyParser.Key.Type`
        func createNode(from key: KeyParser.KeyType) -> URLEncodedFormNode {
            switch key {
            case .array, .arrayWithIndices:
                return .array(.init())
            case .map:
                return .map(.init())
            }
        }

        // get key and remove from list
        let keyType = keys.first
        let keys = keys.dropFirst()

        switch (self, keyType) {
        case (.map(let map), .map(let key)):
            let key = String(key)
            if keys.count == 0 {
                guard map.values[key] == nil else { throw URLEncodedFormError(code: .duplicateKeys, value: key) }
                map.values[key] = .leaf(value)
            } else {
                if let node = map.values[key] {
                    try node.addValue(keys: keys, value: value, key: key)
                } else {
                    let node = createNode(from: keys.first!)
                    map.values[key] = node
                    try node.addValue(keys: keys, value: value, key: key)
                }
            }
        case (.array(let array), .array):
            if keys.count == 0 {
                array.values.append(.leaf(value))
            } else {
                // currently don't support arrays and maps inside arrays
                throw URLEncodedFormError(code: .notSupported, value: key)
            }
        case (.array(let array), .arrayWithIndices(let index)):
            guard keys.count == 0, array.values.count == index else {
                throw URLEncodedFormError(code: .invalidArrayIndex, value: "\(key)[\(index)]")
            }
            array.values.append(.leaf(value))
        case (_, .arrayWithIndices), (_, .array):
            throw URLEncodedFormError(code: .addingToInvalidType, value: key)
        case (_, .map):
            throw URLEncodedFormError(code: .addingToInvalidType, value: key)
        default:
            throw URLEncodedFormError(code: .unexpectedError, value: key)
        }
    }

    /// Create URL encoded string from node
    /// - Parameter prefix: Prefix for string
    /// - Returns: URL encoded string
    private func encode(_ prefix: String) -> String {
        switch self {
        case .leaf(let string):
            return string.map { "\(prefix)=\($0.percentEncoded)" } ?? ""
        case .array(let array):
            return array.values.map {
                $0.encode("\(prefix)[]")
            }.joined(separator: "&")
        case .map(let map):
            if prefix.count == 0 {
                return map.values.map {
                    $0.value.encode("\($0.key)")
                }.joined(separator: "&")
            } else {
                return map.values.map {
                    $0.value.encode("\(prefix)[\($0.key)]")
                }.joined(separator: "&")
            }
        case .empty:
            return ""
        }
    }

    struct NodeValue: Equatable {
        /// string value of node (with percent encoding removed)
        let value: String

        init(_ value: some LosslessStringConvertible) {
            self.value = String(describing: value)
        }

        init?(percentEncoded value: String) {
            guard let value = value.removingURLPercentEncoding() else { return nil }
            self.value = value
        }

        var percentEncoded: String {
            self.value.addingPercentEncoding(forURLComponent: .queryItem)
        }

        static func == (lhs: URLEncodedFormNode.NodeValue, rhs: URLEncodedFormNode.NodeValue) -> Bool {
            lhs.value == rhs.value
        }
    }

    final class Map: Equatable {
        var values: [String: URLEncodedFormNode]
        init(values: [String: URLEncodedFormNode] = [:]) {
            self.values = values
        }

        func addChild(key: String, value: URLEncodedFormNode) {
            self.values[key] = value
        }

        static func == (lhs: URLEncodedFormNode.Map, rhs: URLEncodedFormNode.Map) -> Bool {
            lhs.values == rhs.values
        }
    }

    final class Array: Equatable {
        var values: [URLEncodedFormNode]
        init(values: [URLEncodedFormNode] = []) {
            self.values = values
        }

        func addChild(value: URLEncodedFormNode) {
            self.values.append(value)
        }

        static func == (lhs: URLEncodedFormNode.Array, rhs: URLEncodedFormNode.Array) -> Bool {
            lhs.values == rhs.values
        }
    }
}

/// Parse URL encoded key
enum KeyParser {
    enum KeyType: Equatable {
        case map(Substring)
        case array
        case arrayWithIndices(Int)
    }

    static func parse(_ key: String) -> [KeyType]? {
        var index = key.startIndex
        var values: [KeyType] = []

        guard let bracketIndex = key.firstIndex(of: "[") else {
            index = key.endIndex
            return [.map(key[...])]
        }
        values.append(.map(key[..<bracketIndex]))
        index = bracketIndex

        while index != key.endIndex {
            guard key[index] == "[" else { return nil }
            index = key.index(after: index)
            // an open bracket is unexpected
            guard index != key.endIndex else { return nil }

            if key[index] == "]" {
                values.append(.array)
                index = key.index(after: index)
            } else {
                // an open bracket is unexpected
                guard let bracketIndex = key[index...].firstIndex(of: "]") else { return nil }
                // If key can convert to an integer assume it is an array index
                if let index = Int(key[index..<bracketIndex]) {
                    values.append(.arrayWithIndices(index))
                } else {
                    values.append(.map(key[index..<bracketIndex]))
                }
                index = bracketIndex
                index = key.index(after: index)
            }
        }
        return values
    }
}
