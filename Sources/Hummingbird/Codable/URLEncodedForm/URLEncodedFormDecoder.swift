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

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif os(Linux)
@preconcurrency import Foundation
#else
import Foundation
#endif

/// The wrapper struct for decoding URL encoded form data to Codable classes
public struct URLEncodedFormDecoder: Sendable {
    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy: Sendable {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate

        /// Decode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        case iso8601

        /// Decode the `Date` as a custom value encoded by the given closure.
        case custom(@Sendable (_ decoder: Decoder) throws -> Date)
    }

    /// The strategy to use in Encoding dates. Defaults to `.deferredToDate`.
    public var dateDecodingStrategy: DateDecodingStrategy

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Sendable]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let userInfo: [CodingUserInfoKey: Sendable]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        _Options(
            dateDecodingStrategy: self.dateDecodingStrategy,
            userInfo: self.userInfo
        )
    }

    /// Create URLEncodedFormDecoder
    /// - Parameters:
    ///   - dateDecodingStrategy: date decoding strategy
    ///   - userInfo: user info to supply to decoder
    public init(
        dateDecodingStrategy: URLEncodedFormDecoder.DateDecodingStrategy = .deferredToDate,
        userInfo: [CodingUserInfoKey: Sendable] = [:]
    ) {
        self.dateDecodingStrategy = dateDecodingStrategy
        self.userInfo = userInfo
    }

    /// Decode from URL encoded form data to type
    /// - Parameters:
    ///   - type: Type to decode to
    ///   - string: URL encoded form data
    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let decoder = _URLEncodedFormDecoder(options: self.options)
        let node = try URLEncodedFormNode(from: string)
        let value = try decoder.unbox(node, as: type)
        return value
    }
}

private class _URLEncodedFormDecoder: Decoder {
    // MARK: Properties

    /// The decoder's storage.
    fileprivate var storage: URLEncodedFormDecodingStorage

    /// Options set on the top-level decoder.
    fileprivate let options: URLEncodedFormDecoder._Options

    /// The path to the current point in encoding.
    public fileprivate(set) var codingPath: [CodingKey]

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    fileprivate init(at codingPath: [CodingKey] = [], options: URLEncodedFormDecoder._Options) {
        self.codingPath = codingPath
        self.options = options
        self.storage = .init()
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .map(let map) = self.storage.topContainer else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected a dictionary"))
        }
        return KeyedDecodingContainer(KDC(container: map, decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let array) = self.storage.topContainer else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected an array"))
        }
        return UKDC(container: array, decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }

    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey] { self.decoder.codingPath }
        let decoder: _URLEncodedFormDecoder
        let container: URLEncodedFormNode.Map

        let allKeys: [Key]

        init(container: URLEncodedFormNode.Map, decoder: _URLEncodedFormDecoder) {
            self.decoder = decoder
            self.container = container
            self.allKeys = container.values.keys.compactMap { Key(stringValue: $0) }
        }

        func contains(_ key: Key) -> Bool {
            self.container.values[key.stringValue] != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unboxNil(node)
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Bool.self)
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: String.self)
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Double.self)
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Float.self)
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Int.self)
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Int8.self)
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Int16.self)
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Int32.self)
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: Int64.self)
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: UInt.self)
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: UInt8.self)
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: UInt16.self)
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: UInt32.self)
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: UInt64.self)
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }

            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            return try self.decoder.unbox(node, as: T.self)
        }

        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }

            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            guard case .map(let map) = node else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected a dictionary"))
            }
            let container = KDC<NestedKey>(container: map, decoder: self.decoder)
            return KeyedDecodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }

            guard let node = container.values[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: self.codingPath, debugDescription: ""))
            }
            guard case .array(let array) = node else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected a dictionary"))
            }
            return UKDC(container: array, decoder: self.decoder)
        }

        func superDecoder() throws -> Decoder {
            fatalError()
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError()
        }
    }

    struct UKDC: UnkeyedDecodingContainer {
        let container: URLEncodedFormNode.Array
        let decoder: _URLEncodedFormDecoder
        var codingPath: [CodingKey] { self.decoder.codingPath }
        let count: Int?
        var isAtEnd: Bool { self.currentIndex == self.count }
        var currentIndex: Int

        init(container: URLEncodedFormNode.Array, decoder: _URLEncodedFormDecoder) {
            self.container = container
            self.decoder = decoder
            self.count = container.values.count
            self.currentIndex = 0
        }

        mutating func decodeNextNode<T: Decodable>(as: T.Type = T.self) throws -> T {
            guard !self.isAtEnd else {
                throw DecodingError.valueNotFound(
                    T.self,
                    .init(codingPath: self.codingPath, debugDescription: "Unkeyed container index out of range")
                )
            }
            let node = self.container.values[self.currentIndex]
            self.currentIndex += 1
            return try self.decoder.unbox(node, as: T.self)
        }

        mutating func decodeNil() throws -> Bool {
            let node = self.container.values[self.currentIndex]
            return try self.decoder.unboxNil(node)
        }

        mutating func decode(_: Bool.Type) throws -> Bool {
            try self.decodeNextNode()
        }

        mutating func decode(_: String.Type) throws -> String {
            try self.decodeNextNode()
        }

        mutating func decode(_: Double.Type) throws -> Double {
            try self.decodeNextNode()
        }

        mutating func decode(_: Float.Type) throws -> Float {
            try self.decodeNextNode()
        }

        mutating func decode(_: Int.Type) throws -> Int {
            try self.decodeNextNode()
        }

        mutating func decode(_: Int8.Type) throws -> Int8 {
            try self.decodeNextNode()
        }

        mutating func decode(_: Int16.Type) throws -> Int16 {
            try self.decodeNextNode()
        }

        mutating func decode(_: Int32.Type) throws -> Int32 {
            try self.decodeNextNode()
        }

        mutating func decode(_: Int64.Type) throws -> Int64 {
            try self.decodeNextNode()
        }

        mutating func decode(_: UInt.Type) throws -> UInt {
            try self.decodeNextNode()
        }

        mutating func decode(_: UInt8.Type) throws -> UInt8 {
            try self.decodeNextNode()
        }

        mutating func decode(_: UInt16.Type) throws -> UInt16 {
            try self.decodeNextNode()
        }

        mutating func decode(_: UInt32.Type) throws -> UInt32 {
            try self.decodeNextNode()
        }

        mutating func decode(_: UInt64.Type) throws -> UInt64 {
            try self.decodeNextNode()
        }

        mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
            try self.decodeNextNode()
        }

        mutating func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            guard !self.isAtEnd else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Unkeyed container index out of range"))
            }
            let node = container.values[self.currentIndex]
            self.currentIndex += 1
            guard case .map(let map) = node else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected a dictionary"))
            }
            let container = KDC<NestedKey>(container: map, decoder: self.decoder)
            return KeyedDecodingContainer(container)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard !self.isAtEnd else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Unkeyed container index out of range"))
            }
            let node = self.container.values[self.currentIndex]
            self.currentIndex += 1
            guard case .array(let array) = node else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected an array"))
            }
            return UKDC(container: array, decoder: self.decoder)
        }

        mutating func superDecoder() throws -> Decoder {
            fatalError()
        }
    }
}

extension _URLEncodedFormDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        (try? self.unboxNil(self.storage.topContainer)) ?? false
    }

    func decode(_: Bool.Type) throws -> Bool {
        try self.unbox(self.storage.topContainer, as: Bool.self)
    }

    func decode(_: String.Type) throws -> String {
        try self.unbox(self.storage.topContainer, as: String.self)
    }

    func decode(_: Double.Type) throws -> Double {
        try self.unbox(self.storage.topContainer, as: Double.self)
    }

    func decode(_: Float.Type) throws -> Float {
        try self.unbox(self.storage.topContainer, as: Float.self)
    }

    func decode(_: Int.Type) throws -> Int {
        try self.unbox(self.storage.topContainer, as: Int.self)
    }

    func decode(_: Int8.Type) throws -> Int8 {
        try self.unbox(self.storage.topContainer, as: Int8.self)
    }

    func decode(_: Int16.Type) throws -> Int16 {
        try self.unbox(self.storage.topContainer, as: Int16.self)
    }

    func decode(_: Int32.Type) throws -> Int32 {
        try self.unbox(self.storage.topContainer, as: Int32.self)
    }

    func decode(_: Int64.Type) throws -> Int64 {
        try self.unbox(self.storage.topContainer, as: Int64.self)
    }

    func decode(_: UInt.Type) throws -> UInt {
        try self.unbox(self.storage.topContainer, as: UInt.self)
    }

    func decode(_: UInt8.Type) throws -> UInt8 {
        try self.unbox(self.storage.topContainer, as: UInt8.self)
    }

    func decode(_: UInt16.Type) throws -> UInt16 {
        try self.unbox(self.storage.topContainer, as: UInt16.self)
    }

    func decode(_: UInt32.Type) throws -> UInt32 {
        try self.unbox(self.storage.topContainer, as: UInt32.self)
    }

    func decode(_: UInt64.Type) throws -> UInt64 {
        try self.unbox(self.storage.topContainer, as: UInt64.self)
    }

    func decode<T>(_: T.Type) throws -> T where T: Decodable {
        try self.unbox(self.storage.topContainer, as: T.self)
    }
}

extension _URLEncodedFormDecoder {
    func unboxNil(_ node: URLEncodedFormNode) throws -> Bool {
        guard case .leaf(let value) = node else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expect value not array of dictionary"))
        }
        return value == nil
    }

    func unbox(_ node: URLEncodedFormNode, as type: Bool.Type) throws -> Bool {
        guard case .leaf(let value) = node else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expect value not array of dictionary"))
        }
        if let value2 = value {
            if let unboxValue = Bool(value2.value) {
                return unboxValue
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Bool"))
            }
        } else {
            return false
        }
    }

    func unbox(_ node: URLEncodedFormNode, as type: String.Type) throws -> String {
        guard case .leaf(let value) = node else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expect value not array of dictionary"))
        }
        guard let value2 = value else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected value not empty string"))
        }
        return value2.value
    }

    func unbox(_ node: URLEncodedFormNode, as type: Double.Type) throws -> Double {
        guard let unboxValue = try Double(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Double"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Float.Type) throws -> Float {
        guard let unboxValue = try Float(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Float"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Int.Type) throws -> Int {
        guard let unboxValue = try Int(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Int"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Int8.Type) throws -> Int8 {
        guard let unboxValue = try Int8(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Int8"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Int16.Type) throws -> Int16 {
        guard let unboxValue = try Int16(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Int16"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Int32.Type) throws -> Int32 {
        guard let unboxValue = try Int32(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Int32"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Int64.Type) throws -> Int64 {
        guard let unboxValue = try Int64(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected Int64"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: UInt.Type) throws -> UInt {
        guard let unboxValue = try UInt(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected UInt"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: UInt8.Type) throws -> UInt8 {
        guard let unboxValue = try UInt8(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected UInt8"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: UInt16.Type) throws -> UInt16 {
        guard let unboxValue = try UInt16(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected UInt16"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: UInt32.Type) throws -> UInt32 {
        guard let unboxValue = try UInt32(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected UInt32"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: UInt64.Type) throws -> UInt64 {
        guard let unboxValue = try UInt64(unbox(node, as: String.self)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Expected UInt64"))
        }
        return unboxValue
    }

    func unbox(_ node: URLEncodedFormNode, as type: Date.Type) throws -> Date {
        switch self.options.dateDecodingStrategy {
        case .deferredToDate:
            self.storage.push(container: node)
            defer { self.storage.popContainer() }
            return try .init(from: self)
        case .millisecondsSince1970:
            let milliseconds = try unbox(node, as: Double.self)
            return Date(timeIntervalSince1970: milliseconds / 1000)
        case .secondsSince1970:
            let seconds = try unbox(node, as: Double.self)
            return Date(timeIntervalSince1970: seconds)
        case .iso8601:
            let dateString = try unbox(node, as: String.self)
            #if compiler(>=6.0)
            guard let date = try? Date(dateString, strategy: .iso8601) else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Invalid date format"))
            }
            #else
            guard let date = URLEncodedForm.iso8601Formatter.date(from: dateString) else {
                throw DecodingError.dataCorrupted(.init(codingPath: self.codingPath, debugDescription: "Invalid date format"))
            }
            #endif
            return date
        case .custom(let closure):
            self.storage.push(container: node)
            defer { self.storage.popContainer() }
            return try closure(self)
        }
    }

    func unbox(_ node: URLEncodedFormNode, as type: Data.Type) throws -> Data {
        let string = try unbox(node, as: String.self)
        guard let data = Data(base64Encoded: string) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: self.codingPath, debugDescription: "Encountered Data is not valid Base64.")
            )
        }
        return data
    }

    func unbox<T>(_ node: URLEncodedFormNode, as type: T.Type) throws -> T where T: Decodable {
        try self.unbox_(node, as: T.self) as! T
    }

    func unbox_(_ node: URLEncodedFormNode, as type: Decodable.Type) throws -> Any {
        if type == Data.self {
            return try self.unbox(node, as: Data.self)
        } else if type == Date.self {
            return try self.unbox(node, as: Date.self)
        } else {
            self.storage.push(container: node)
            defer { self.storage.popContainer() }
            return try type.init(from: self)
        }
    }
}

private struct URLEncodedFormDecodingStorage {
    /// the container stack
    private var containers: [URLEncodedFormNode] = []

    /// initializes self with no containers
    init() {}

    /// return the container at the top of the storage
    var topContainer: URLEncodedFormNode { self.containers.last! }

    /// push a new container onto the storage
    mutating func push(container: URLEncodedFormNode) { self.containers.append(container) }

    /// pop a container from the storage
    @discardableResult mutating func popContainer() -> URLEncodedFormNode { self.containers.removeLast() }
}
