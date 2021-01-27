import Foundation

/// The wrapper struct for encoding Codable classes to URL encoded form data
public struct URLEncodedFormEncoder {

    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy {
        /// Defer to `Date` for encoding. This is the default strategy.
        case deferredToDate

        /// Encode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Encode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Encode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Encode the `Date` as a custom value encoded by the given closure.
        case custom((Date, Encoder) throws -> Void)
    }

    /// The strategy to use in Encoding dates. Defaults to `.deferredToDate`.
    public var dateEncodingStrategy: DateEncodingStrategy

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any]

    /// additional keys to include
    public var additionalKeys: [String: String]

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

    public init(
        dateEncodingStrategy: URLEncodedFormEncoder.DateEncodingStrategy = .deferredToDate,
        userInfo: [CodingUserInfoKey : Any] = [:],
        additionalKeys: [String : String] = [:]
    ) {
        self.dateEncodingStrategy = dateEncodingStrategy
        self.userInfo = userInfo
        self.additionalKeys = additionalKeys
    }

    public func encode<T: Encodable>(_ value: T, name: String? = nil) throws -> String? {
        let encoder = _URLEncodedFormEncoder(options: options)
        try value.encode(to: encoder)

        // encode generates a tree of dictionaries and arrays. We need to flatten this into a single dictionary with keys joined together
        let result = flatten(encoder.result)
        return Self.urlEncodeParams(dictionary: result)
    }
}

extension URLEncodedFormEncoder {
    private static func urlEncodeParam(_ value: String) -> String {
        return value.addingPercentEncoding(withAllowedCharacters: URLEncodedForm.unreservedCharacters) ?? value
    }

    // generate string from
    private static func urlEncodeParams(dictionary: [(key: String, value: String)]) -> String? {
        guard dictionary.count > 0 else { return nil }
        return dictionary
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(urlEncodeParam(String(describing: $0.value)))" }
            .joined(separator: "&")
    }

    /// Flatten dictionary and array tree into one dictionary
    /// - Parameter container: The root container
    private func flatten(_ container: URLEncodedFormEncoderKeyedContainer?) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = additionalKeys.map { return $0 }

        func flatten(dictionary: [String: Any], path: String) {
            for (key, value) in dictionary {
                switch value {
                case let keyed as URLEncodedFormEncoderKeyedContainer:
                    flatten(dictionary: keyed.values, path: "\(path)\(key).")
                case let unkeyed as URLEncodedFormEncoderUnkeyedContainer:
                    flatten(array: unkeyed.values, path: "\(path)\(key).")
                default:
                    result.append((key: "\(path)\(key)", value: String(describing: value)))
                }
            }
        }
        func flatten(array: [Any], path: String) {
            for iterator in array.enumerated() {
                switch iterator.element {
                case let keyed as URLEncodedFormEncoderKeyedContainer:
                    flatten(dictionary: keyed.values, path: "\(path)\(iterator.offset + 1).")
                case let unkeyed as URLEncodedFormEncoderUnkeyedContainer:
                    flatten(array: unkeyed.values, path: "\(path)\(iterator.offset + 1)")
                default:
                    result.append((key: "\(path)\(iterator.offset + 1)", value: String(describing: iterator.element)))
                }
            }
        }
        if let container = container {
            flatten(dictionary: container.values, path: "")
        }
        return result
    }
}

/// class for holding a keyed container (dictionary). Need to encapsulate dictionary in class so we can be sure we are
/// editing the dictionary we push onto the stack
private class URLEncodedFormEncoderKeyedContainer {
    private(set) var values: [String: Any] = [:]

    func addChild(path: String, child: Any) {
        values[path] = child
    }
}

/// class for holding unkeyed container (array). Need to encapsulate array in class so we can be sure we are
/// editing the array we push onto the stack
private class URLEncodedFormEncoderUnkeyedContainer {
    private(set) var values: [Any] = []

    func addChild(_ child: Any) {
        values.append(child)
    }
}

/// storage for Query Encoder. Stores a stack of QueryEncoder containers, plus leaf objects
private struct URLEncodedFormEncoderStorage {
    /// the container stack
    private var containers: [Any] = []

    /// initializes self with no containers
    init() {}

    /// push a new container onto the storage
    mutating func pushKeyedContainer() -> URLEncodedFormEncoderKeyedContainer {
        let container = URLEncodedFormEncoderKeyedContainer()
        containers.append(container)
        return container
    }

    /// push a new container onto the storage
    mutating func pushUnkeyedContainer() -> URLEncodedFormEncoderUnkeyedContainer {
        let container = URLEncodedFormEncoderUnkeyedContainer()
        containers.append(container)
        return container
    }

    mutating func push(container: Any) {
        containers.append(container)
    }

    /// pop a container from the storage
    @discardableResult mutating func popContainer() -> Any {
        return containers.removeLast()
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
    var result: URLEncodedFormEncoderKeyedContainer?

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
        let newContainer = storage.pushKeyedContainer()
        if self.result == nil {
            self.result = newContainer
        }
        return KeyedEncodingContainer(KEC(referencing: self, container: newContainer))
    }

    struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey] { return encoder.codingPath }
        let container: URLEncodedFormEncoderKeyedContainer
        let encoder: _URLEncodedFormEncoder

        /// Initialization
        /// - Parameter referencing: encoder that created this
        init(referencing: _URLEncodedFormEncoder, container: URLEncodedFormEncoderKeyedContainer) {
            self.encoder = referencing
            self.container = container
        }

        mutating func encode(_ value: Any, key: String) {
            container.addChild(path: key, child: value)
        }

        mutating func encodeNil(forKey key: Key) throws { encode("", key: key.stringValue) }
        mutating func encode(_ value: Bool, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: String, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Double, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Float, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int8, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int16, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int32, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: Int64, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt8, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt16, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt32, forKey key: Key) throws { encode(value, key: key.stringValue) }
        mutating func encode(_ value: UInt64, forKey key: Key) throws { encode(value, key: key.stringValue) }

        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let childContainer = try encoder.box(value)
            container.addChild(path: key.stringValue, child: childContainer)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let keyedContainer = URLEncodedFormEncoderKeyedContainer()
            container.addChild(path: key.stringValue, child: keyedContainer)

            let kec = KEC<NestedKey>(referencing: self.encoder, container: keyedContainer)
            return KeyedEncodingContainer(kec)
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }

            let unkeyedContainer = URLEncodedFormEncoderUnkeyedContainer()
            container.addChild(path: key.stringValue, child: unkeyedContainer)

            return UKEC(referencing: self.encoder, container: unkeyedContainer)
        }

        mutating func superEncoder() -> Encoder {
            return encoder
        }

        mutating func superEncoder(forKey key: Key) -> Encoder {
            return encoder
        }
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = storage.pushUnkeyedContainer()
        return UKEC(referencing: self, container: container)
    }

    struct UKEC: UnkeyedEncodingContainer {
        var codingPath: [CodingKey] { return encoder.codingPath }
        let container: URLEncodedFormEncoderUnkeyedContainer
        let encoder: _URLEncodedFormEncoder
        var count: Int

        init(referencing: _URLEncodedFormEncoder, container: URLEncodedFormEncoderUnkeyedContainer) {
            self.encoder = referencing
            self.container = container
            self.count = 0
        }

        mutating func encodeResult(_ value: Any) {
            count += 1
            container.addChild(value)
        }

        mutating func encodeNil() throws { encodeResult("") }
        mutating func encode(_ value: Bool) throws { encodeResult(value) }
        mutating func encode(_ value: String) throws { encodeResult(value) }
        mutating func encode(_ value: Double) throws { encodeResult(value) }
        mutating func encode(_ value: Float) throws { encodeResult(value) }
        mutating func encode(_ value: Int) throws { encodeResult(value) }
        mutating func encode(_ value: Int8) throws { encodeResult(value) }
        mutating func encode(_ value: Int16) throws { encodeResult(value) }
        mutating func encode(_ value: Int32) throws { encodeResult(value) }
        mutating func encode(_ value: Int64) throws { encodeResult(value) }
        mutating func encode(_ value: UInt) throws { encodeResult(value) }
        mutating func encode(_ value: UInt8) throws { encodeResult(value) }
        mutating func encode(_ value: UInt16) throws { encodeResult(value) }
        mutating func encode(_ value: UInt32) throws { encodeResult(value) }
        mutating func encode(_ value: UInt64) throws { encodeResult(value) }

        mutating func encode<T: Encodable>(_ value: T) throws {
            count += 1

            self.encoder.codingPath.append(URLEncodedForm.Key(index: count))
            defer { self.encoder.codingPath.removeLast() }

            let childContainer = try encoder.box(value)
            container.addChild(childContainer)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            count += 1

            self.encoder.codingPath.append(URLEncodedForm.Key(index: count))
            defer { self.encoder.codingPath.removeLast() }

            let keyedContainer = URLEncodedFormEncoderKeyedContainer()
            container.addChild(keyedContainer)

            let kec = KEC<NestedKey>(referencing: self.encoder, container: keyedContainer)
            return KeyedEncodingContainer(kec)
        }

        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            count += 1

            let unkeyedContainer = URLEncodedFormEncoderUnkeyedContainer()
            container.addChild(unkeyedContainer)

            return UKEC(referencing: self.encoder, container: unkeyedContainer)
        }

        mutating func superEncoder() -> Encoder {
            return encoder
        }
    }
}

extension _URLEncodedFormEncoder: SingleValueEncodingContainer {
    func encodeResult(_ value: Any) {
        storage.push(container: value)
    }

    func encodeNil() throws {
        encodeResult("")
    }

    func encode(_ value: Bool) throws { encodeResult(value) }
    func encode(_ value: String) throws { encodeResult(value) }
    func encode(_ value: Double) throws { encodeResult(value) }
    func encode(_ value: Float) throws { encodeResult(value) }
    func encode(_ value: Int) throws { encodeResult(value) }
    func encode(_ value: Int8) throws { encodeResult(value) }
    func encode(_ value: Int16) throws { encodeResult(value) }
    func encode(_ value: Int32) throws { encodeResult(value) }
    func encode(_ value: Int64) throws { encodeResult(value) }
    func encode(_ value: UInt) throws { encodeResult(value) }
    func encode(_ value: UInt8) throws { encodeResult(value) }
    func encode(_ value: UInt16) throws { encodeResult(value) }
    func encode(_ value: UInt32) throws { encodeResult(value) }
    func encode(_ value: UInt64) throws { encodeResult(value) }

    func encode<T: Encodable>(_ value: T) throws {
        try value.encode(to: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

extension _URLEncodedFormEncoder {
    func box(_ date: Date) throws -> Any {
        switch options.dateEncodingStrategy {
        case .deferredToDate:
            try date.encode(to: self)
        case .millisecondsSince1970:
            try encode(Int(date.timeIntervalSince1970 * 1000).description)
        case .secondsSince1970:
            try encode(Int(date.timeIntervalSince1970).description)
        case .iso8601:
            if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                try encode(Self.iso8601Formatter.string(from: date))
            } else {
                preconditionFailure("ISO8601DateFormatter is unavailable on this platform")
            }
        case .formatted(let formatter):
            try encode(formatter.string(from: date))
        case .custom(let closure):
            try closure(date, self)
        }
        return storage.popContainer()
    }

    func box(_ data: Data) throws -> Any {
        try encode(data.base64EncodedString())
        return storage.popContainer()
    }

    func box(_ value: Encodable) throws -> Any {
        let type = Swift.type(of: value)
        if type == Data.self {
            return try self.box(value as! Data)
        } else if type == Date.self {
            return try self.box(value as! Date)
        } else {
            try value.encode(to: self)
            return storage.popContainer()
        }
    }

    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    fileprivate static var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()
}
