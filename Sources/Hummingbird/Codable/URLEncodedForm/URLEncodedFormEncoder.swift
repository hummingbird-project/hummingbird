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

#if os(Linux)
@preconcurrency import Foundation
#else
import Foundation
#endif

/// The wrapper struct for encoding Codable classes to URL encoded form data
public struct URLEncodedFormEncoder: Sendable {
    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy: Sendable {
        /// Defer to `Date` for encoding. This is the default strategy.
        case deferredToDate

        /// Encode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Encode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        case iso8601

        /// Encode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Encode the `Date` as a custom value encoded by the given closure.
        case custom(@Sendable (Date, Encoder) throws -> Void)
    }

    /// The strategy to use in Encoding dates. Defaults to `.deferredToDate`.
    public var dateEncodingStrategy: DateEncodingStrategy

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Sendable]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let dateEncodingStrategy: DateEncodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(
            dateEncodingStrategy: self.dateEncodingStrategy,
            userInfo: self.userInfo
        )
    }

    /// Create URLEncodedFormEncoder
    /// - Parameters:
    ///   - dateEncodingStrategy: date encoding strategy
    ///   - userInfo: user info to supply to encoder
    ///   - additionalKeys: Deprecated variable
    public init(
        dateEncodingStrategy: URLEncodedFormEncoder.DateEncodingStrategy = .deferredToDate,
        userInfo: [CodingUserInfoKey: Sendable] = [:],
        additionalKeys: [String: String] = [:]
    ) {
        self.dateEncodingStrategy = dateEncodingStrategy
        self.userInfo = userInfo
    }

    /// Encode object into URL encoded form data
    /// - Parameters:
    ///   - value: Value to encode
    /// - Returns: URL encoded form data
    public func encode(_ value: some Encodable) throws -> String {
        let encoder = _URLEncodedFormEncoder(options: options)
        try value.encode(to: encoder)
        guard let result = encoder.result else {
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "URLEncodedFormEncoder cannot be used to encode arrays"))
        }
        return result.description
    }
}

/// Internal QueryEncoder class. Does all the heavy lifting
private class _URLEncodedFormEncoder: Encoder {
    var codingPath: [CodingKey]

    /// the encoder's storage
    var storage: URLEncodedFormEncoderStorage

    /// options
    var options: URLEncodedFormEncoder._Options

    /// resultant url encoded array
    var result: URLEncodedFormNode?

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] {
        return self.options.userInfo
    }

    /// Initialization
    /// - Parameters:
    ///   - options: options
    ///   - containerCodingMapType: Container encoding for the top level object
    init(options: URLEncodedFormEncoder._Options) {
        self.storage = URLEncodedFormEncoderStorage()
        self.options = options
        self.codingPath = []
        self.result = nil
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let keyedContainer = self.storage.pushKeyedContainer()
        if self.result == nil {
            self.result = .map(keyedContainer)
        }
        return KeyedEncodingContainer(KEC(referencing: self, container: keyedContainer))
    }

    struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey] { return self.encoder.codingPath }
        let container: URLEncodedFormNode.Map
        let encoder: _URLEncodedFormEncoder

        /// Initialization
        /// - Parameter referencing: encoder that created this
        init(referencing: _URLEncodedFormEncoder, container: URLEncodedFormNode.Map) {
            self.encoder = referencing
            self.container = container
        }

        mutating func encode(_ value: URLEncodedFormNode, key: String) {
            self.container.addChild(key: key, value: value)
        }

        mutating func encode(_ value: LosslessStringConvertible, key: String) {
            self.encode(.leaf(.init(value)), key: key)
        }

        mutating func encodeNil(forKey key: Key) throws { self.encode("", key: key.stringValue) }
        mutating func encode(_ value: Bool, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: String, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Double, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Float, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int8, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int16, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int32, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int64, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt8, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt16, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt32, forKey key: Key) throws { self.encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt64, forKey key: Key) throws { self.encode(value, key: key.stringValue) }

        mutating func encode(_ value: some Encodable, forKey key: Key) throws {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let childContainer = try encoder.box(value)
            self.container.addChild(key: key.stringValue, value: childContainer)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let keyedContainer = URLEncodedFormNode.Map()
            self.container.addChild(key: key.stringValue, value: .map(keyedContainer))

            let kec = KEC<NestedKey>(referencing: self.encoder, container: keyedContainer)
            return KeyedEncodingContainer(kec)
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let unkeyedContainer = URLEncodedFormNode.Array()
            self.container.addChild(key: key.stringValue, value: .array(unkeyedContainer))

            return UKEC(referencing: self.encoder, container: unkeyedContainer)
        }

        mutating func superEncoder() -> Encoder {
            return self.encoder
        }

        mutating func superEncoder(forKey key: Key) -> Encoder {
            return self.encoder
        }
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = self.storage.pushUnkeyedContainer()
        return UKEC(referencing: self, container: container)
    }

    struct UKEC: UnkeyedEncodingContainer {
        var codingPath: [CodingKey] { return self.encoder.codingPath }
        let container: URLEncodedFormNode.Array
        let encoder: _URLEncodedFormEncoder
        var count: Int

        init(referencing: _URLEncodedFormEncoder, container: URLEncodedFormNode.Array) {
            self.encoder = referencing
            self.container = container
            self.count = 0
        }

        mutating func encodeResult(_ value: URLEncodedFormNode) {
            self.count += 1
            self.container.addChild(value: value)
        }

        mutating func encodeResult(_ value: LosslessStringConvertible) {
            self.encodeResult(.leaf(.init(value)))
        }

        mutating func encodeNil() throws { self.encodeResult("") }
        mutating func encode(_ value: Bool) throws { self.encodeResult(value) }
        mutating func encode(_ value: String) throws { self.encodeResult(value) }
        mutating func encode(_ value: Double) throws { self.encodeResult(value) }
        mutating func encode(_ value: Float) throws { self.encodeResult(value) }
        mutating func encode(_ value: Int) throws { self.encodeResult(value) }
        mutating func encode(_ value: Int8) throws { self.encodeResult(value) }
        mutating func encode(_ value: Int16) throws { self.encodeResult(value) }
        mutating func encode(_ value: Int32) throws { self.encodeResult(value) }
        mutating func encode(_ value: Int64) throws { self.encodeResult(value) }
        mutating func encode(_ value: UInt) throws { self.encodeResult(value) }
        mutating func encode(_ value: UInt8) throws { self.encodeResult(value) }
        mutating func encode(_ value: UInt16) throws { self.encodeResult(value) }
        mutating func encode(_ value: UInt32) throws { self.encodeResult(value) }
        mutating func encode(_ value: UInt64) throws { self.encodeResult(value) }

        mutating func encode(_ value: some Encodable) throws {
            self.count += 1

            self.encoder.codingPath.append(URLEncodedForm.Key(index: self.count))
            defer { self.encoder.codingPath.removeLast() }

            let childContainer = try encoder.box(value)
            self.container.addChild(value: childContainer)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            self.count += 1

            self.encoder.codingPath.append(URLEncodedForm.Key(index: self.count))
            defer { self.encoder.codingPath.removeLast() }

            let keyedContainer = URLEncodedFormNode.Map()
            self.container.addChild(value: .map(keyedContainer))

            let kec = KEC<NestedKey>(referencing: self.encoder, container: keyedContainer)
            return KeyedEncodingContainer(kec)
        }

        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            self.count += 1

            let unkeyedContainer = URLEncodedFormNode.Array()
            self.container.addChild(value: .array(unkeyedContainer))

            return UKEC(referencing: self.encoder, container: unkeyedContainer)
        }

        mutating func superEncoder() -> Encoder {
            return self.encoder
        }
    }
}

extension _URLEncodedFormEncoder: SingleValueEncodingContainer {
    func encodeResult(_ value: URLEncodedFormNode) {
        self.storage.push(container: value)
    }

    func encodeResult(_ value: LosslessStringConvertible) {
        self.storage.push(container: .leaf(.init(value)))
    }

    func encodeNil() throws {
        self.encodeResult("")
    }

    func encode(_ value: Bool) throws { self.encodeResult(value) }
    func encode(_ value: String) throws { self.encodeResult(value) }
    func encode(_ value: Double) throws { self.encodeResult(value) }
    func encode(_ value: Float) throws { self.encodeResult(value) }
    func encode(_ value: Int) throws { self.encodeResult(value) }
    func encode(_ value: Int8) throws { self.encodeResult(value) }
    func encode(_ value: Int16) throws { self.encodeResult(value) }
    func encode(_ value: Int32) throws { self.encodeResult(value) }
    func encode(_ value: Int64) throws { self.encodeResult(value) }
    func encode(_ value: UInt) throws { self.encodeResult(value) }
    func encode(_ value: UInt8) throws { self.encodeResult(value) }
    func encode(_ value: UInt16) throws { self.encodeResult(value) }
    func encode(_ value: UInt32) throws { self.encodeResult(value) }
    func encode(_ value: UInt64) throws { self.encodeResult(value) }

    func encode(_ value: some Encodable) throws {
        try value.encode(to: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

extension _URLEncodedFormEncoder {
    func box(_ date: Date) throws -> URLEncodedFormNode {
        switch self.options.dateEncodingStrategy {
        case .deferredToDate:
            try date.encode(to: self)
        case .millisecondsSince1970:
            try self.encode(Double(date.timeIntervalSince1970 * 1000).description)
        case .secondsSince1970:
            try self.encode(Double(date.timeIntervalSince1970).description)
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                try encode(URLEncodedForm.iso8601Formatter.string(from: date))
            } else {
                preconditionFailure("ISO8601DateFormatter is unavailable on this platform")
            }
        case .formatted(let formatter):
            try self.encode(formatter.string(from: date))
        case .custom(let closure):
            try closure(date, self)
        }
        return self.storage.popContainer()
    }

    func box(_ data: Data) throws -> URLEncodedFormNode {
        try self.encode(data.base64EncodedString())
        return self.storage.popContainer()
    }

    func box(_ value: Encodable) throws -> URLEncodedFormNode {
        let type = Swift.type(of: value)
        if type == Data.self {
            return try self.box(value as! Data)
        } else if type == Date.self {
            return try self.box(value as! Date)
        } else {
            try value.encode(to: self)
            return self.storage.popContainer()
        }
    }
}

/// storage for Query Encoder. Stores a stack of QueryEncoder containers, plus leaf objects
private struct URLEncodedFormEncoderStorage {
    /// the container stack
    private var containers: [URLEncodedFormNode] = []

    /// initializes self with no containers
    init() {
        // containers.append(.map(.init()))
    }

    /// push a new container onto the storage
    mutating func pushKeyedContainer() -> URLEncodedFormNode.Map {
        let map = URLEncodedFormNode.Map()
        self.containers.append(.map(map))
        return map
    }

    /// push a new container onto the storage
    mutating func pushUnkeyedContainer() -> URLEncodedFormNode.Array {
        let array = URLEncodedFormNode.Array()
        self.containers.append(.array(array))
        return array
    }

    mutating func push(container: URLEncodedFormNode) {
        self.containers.append(container)
    }

    /// pop a container from the storage
    @discardableResult mutating func popContainer() -> URLEncodedFormNode {
        return self.containers.removeLast()
    }
}
