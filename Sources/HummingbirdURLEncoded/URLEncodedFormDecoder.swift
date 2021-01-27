import Foundation
/*
/// The wrapper struct for decoding URL encoded form data to Codable classes
public struct URLEncodedFormDecoder {

    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {
        /// Defer to `Date` for decoding. This is the default strategy.
        case deferredToDate

        /// Decode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Decode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)

        /// Decode the `Date` as a custom value encoded by the given closure.
        case custom((_ decoder: Decoder) throws -> Date)
    }

    /// The strategy to use in Encoding dates. Defaults to `.deferredToDate`.
    public var dateDecodingStrategy: DateDecodingStrategy

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any]

    /// additional keys to include
    public var additionalKeys: [String: String]

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        let dateDecodingStrategy: DateDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options {
        return _Options(
            dateDecodingStrategy: self.dateDecodingStrategy,
            userInfo: self.userInfo
        )
    }

    public init(
        dateDecodingStrategy: URLEncodedFormDecoder.DateDecodingStrategy = .deferredToDate,
        userInfo: [CodingUserInfoKey : Any] = [:],
        additionalKeys: [String : String] = [:]
    ) {
        self.dateDecodingStrategy = dateDecodingStrategy
        self.userInfo = userInfo
        self.additionalKeys = additionalKeys
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let dictionary = try unpack(string)
        let decoder = _URLEncodedFormDecoder(referencing: dictionary, options: self.options)
        guard let value = try decoder.unbox(string, as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
        }

        return value
    }
}

extension URLEncodedFormDecoder {
    func unpack(_ string: String) throws -> [(String, String)] {
        var entries: [(String, String)]
        let split = string.split(separator: "&")
        try split.forEach {
            if let equals = $0.firstIndex(of: "=") {
                let before = $0[..<equals].removingPercentEncoding
                let afterEquals = $0.index(after: equals)
                let after = $0[afterEquals...].removingPercentEncoding
                guard let key = before, let value = after else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Failed to percent decode \($0)"))}
                entries.append((key, value))
            }
        }
        entries.sort { $0.0 < $1.0 }
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
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    fileprivate init(referencing container: [(String, String)], at codingPath: [CodingKey] = [], options: URLEncodedFormDecoder._Options) {
        self.codingPath = codingPath
        self.options = options
        self.storage.push(container: container[...])
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard let container = storage.topContainer else {
            throw DecodingError.keyNotFound(codingPath.last!, DecodingError.Context(codingPath: codingPath, debugDescription: "Key not found"))
        }
        return KeyedDecodingContainer(KDC(container: container, decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UKDC(decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return self
    }

    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey] { decoder.codingPath }
        let decoder: Decoder
        let container: URLEncodedFormContainer

        var allKeys: [Key]

        init(container: URLEncodedFormContainer, decoder: Decoder) {
            self.decoder = decoder
            self.container = container
            self.allKeys = []
        }

        func contains(_ key: Key) -> Bool {
            <#code#>
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            <#code#>
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            <#code#>
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            <#code#>
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            <#code#>
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            <#code#>
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            <#code#>
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            <#code#>
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            <#code#>
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            <#code#>
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            <#code#>
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            <#code#>
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            <#code#>
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            <#code#>
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            <#code#>
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            <#code#>
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            <#code#>
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            <#code#>
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            <#code#>
        }

        func superDecoder() throws -> Decoder {
            <#code#>
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            <#code#>
        }

    }

    struct UKDC: UnkeyedDecodingContainer {
        let container: URLEncodedFormContainer
        let decoder: Decoder
        var codingPath: [CodingKey] { decoder.codingPath }
        let count: Int?
        var isAtEnd: Bool { self.currentIndex == self.count}
        var currentIndex: Int

        init(container: URLEncodedFormContainer, decoder: Decoder) {
            self.container = container
            self.decoder = decoder
            self.count = 0
            self.currentIndex = 0
        }

        mutating func decodeNil() throws -> Bool {
            <#code#>
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            <#code#>
        }

        mutating func decode(_ type: String.Type) throws -> String {
            <#code#>
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            <#code#>
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            <#code#>
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            <#code#>
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            <#code#>
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            <#code#>
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            <#code#>
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            <#code#>
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            <#code#>
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            <#code#>
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            <#code#>
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            <#code#>
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            <#code#>
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            <#code#>
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            <#code#>
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            <#code#>
        }

        mutating func superDecoder() throws -> Decoder {
            <#code#>
        }

    }
}

extension _URLEncodedFormDecoder: SingleValueDecodingContainer {
    func decodeNil() -> Bool {
        <#code#>
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        <#code#>
    }

    func decode(_ type: String.Type) throws -> String {
        <#code#>
    }

    func decode(_ type: Double.Type) throws -> Double {
        <#code#>
    }

    func decode(_ type: Float.Type) throws -> Float {
        <#code#>
    }

    func decode(_ type: Int.Type) throws -> Int {
        <#code#>
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        <#code#>
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        <#code#>
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        <#code#>
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        <#code#>
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        <#code#>
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        <#code#>
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        <#code#>
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        <#code#>
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        <#code#>
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        <#code#>
    }


}

extension _URLEncodedFormDecoder {

    func unbox<T>(_ element: XML.Node?, as type: T.Type) throws -> T where T: Decodable {
        return try unbox_(element, as: T.self) as! T
    }

    func unbox_(_ element: XML.Node?, as type: Decodable.Type) throws -> Any {
        if type == Data.self {
            return try self.unbox(element, as: Data.self)
        } else if type == Date.self {
            return try self.unbox(element, as: Date.self)
        } else {
            self.storage.push(container: element)
            defer { self.storage.popContainer() }
            return try type.init(from: self)
        }
    }
}

typealias URLEncodedFormContainer = ArraySlice<(String, String)>

private struct URLEncodedFormDecodingStorage {
    /// the container stack
    private var containers: [URLEncodedFormContainer?] = []

    /// initializes self with no containers
    init() {}

    /// return the container at the top of the storage
    var topContainer: URLEncodedFormContainer? { return containers.last! }

    /// push a new container onto the storage
    mutating func push(container: URLEncodedFormContainer?) { containers.append(container) }

    /// pop a container from the storage
    @discardableResult mutating func popContainer() -> URLEncodedFormContainer? { return containers.removeLast() }

}
*/
