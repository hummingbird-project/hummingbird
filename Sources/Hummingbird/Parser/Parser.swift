// Parser.swift
//
// Half inspired by Reader class from John Sundell's Ink project
// https://github.com/JohnSundell/Ink/blob/master/Sources/Ink/Internal/Reader.swift
// with optimisation working ie removing String and doing my own UTF8 processing inspired by Fabian Fett's work in
// https://github.com/fabianfett/pure-swift-json/blob/master/Sources/PureSwiftJSONParsing/DocumentReader.swift
//

import Foundation

/// Reader object for parsing String buffers
public struct Parser {
    public enum Error : Swift.Error {
        case overflow
        case unexpected
        case emptyString
        case invalidUTF8
    }

    /// Create a Parser object
    /// - Parameter string: UTF8 data to parse
    public init?<Bytes: Collection>(_ utf8Data: Bytes, validateUTF8: Bool = true) where Bytes.Element == UInt8 {
        if let buffer = utf8Data as? [UInt8] {
            self.buffer = buffer
        } else {
            self.buffer = Array(utf8Data)
        }
        self.index = 0
        self.range = 0..<buffer.endIndex

        // should check that the data is valid utf8
        if validateUTF8 == true && self.validateUTF8() == false {
            return nil
        }
    }

    public init(_ string: String) {
        self.buffer = Array(string.utf8)
        self.index = 0
        self.range = 0..<buffer.endIndex
    }

    /// Return contents of parser as a string
    public var count: Int {
        return range.count
    }

    /// Return contents of parser as a string
    public var string: String {
        return makeString(buffer[range])
    }

    private var buffer: [UInt8]
    private var index: Int
    private let range: Range<Int>
}

//MARK: sub-parsers
extension Parser {
    /// initialise a parser that parses a section of the buffer attached to another parser
    init(_ parser: Parser, range: Range<Int>) {
        self.buffer = parser.buffer
        self.index = range.startIndex
        self.range = range

        precondition(range.startIndex >= 0 && range.endIndex <= buffer.endIndex)
        precondition(buffer[range.startIndex] & 0xc0 != 0x80) // check we arent in the middle of a UTF8 character
    }

    /// initialise a parser that parses a section of the buffer attached to this parser
    func subParser(_ range: Range<Int>) -> Parser {
        return Parser(self, range: range)
    }
}

public extension Parser {

    /// Return current character
    /// - Throws: .overflow
    /// - Returns: Current character
    mutating func character() throws -> Unicode.Scalar {
        guard !reachedEnd() else { throw Error.overflow }
        return unsafeCurrentAndAdvance()
    }

    /// Read the current character and return if it is as intended. If character test returns true then move forward 1
    /// - Parameter char: character to compare against
    /// - Throws: .overflow
    /// - Returns: If current character was the one we expected
    mutating func read(_ char: Unicode.Scalar) throws -> Bool {
        let initialIndex = index
        let c = try character()
        guard c == char else { self.index = initialIndex; return false }
        return true
    }

    /// Read the current character and check if it is in a set of characters If character test returns true then move forward 1
    /// - Parameter characterSet: Set of characters to compare against
    /// - Throws: .overflow
    /// - Returns: If current character is in character set
    mutating func read(_ characterSet: Set<Unicode.Scalar>) throws -> Bool {
        let initialIndex = index
        let c = try character()
        guard characterSet.contains(c) else { self.index = initialIndex; return false }
        return true
    }

    /// Compare characters at current position against provided string. If the characters are the same as string provided advance past string
    /// - Parameter string: String to compare against
    /// - Throws: .overflow, .emptyString
    /// - Returns: If characters at current position equal string
    mutating func read(_ string: String) throws -> Bool {
        let initialIndex = index
        guard string.count > 0 else { throw Error.emptyString }
        let subString = try read(count: string.count)
        guard subString.string == string else { self.index = initialIndex; return false }
        return true
    }

    /// Read next so many characters from buffer
    /// - Parameter count: Number of characters to read
    /// - Throws: .overflow
    /// - Returns: The string read from the buffer
    mutating func read(count: Int) throws -> Parser {
        var count = count
        var readEndIndex = index
        while count > 0 {
            guard readEndIndex != range.endIndex else { throw Error.overflow }
            readEndIndex = skipUTF8Character(at: readEndIndex)
            count -= 1
        }
        let result = subParser(index..<readEndIndex)
        index = readEndIndex
        return result
    }

    /// Read from buffer until we hit a character. Position after this is of the character we were checking for
    /// - Parameter until: Unicode.Scalar to read until
    /// - Throws: .overflow if we hit the end of the buffer before reading character
    /// - Returns: String read from buffer
    @discardableResult mutating func read(until: Unicode.Scalar, throwOnOverflow: Bool = true) throws -> Parser {
        let startIndex = index
        while !reachedEnd() {
            if unsafeCurrent() == until {
                return subParser(startIndex..<index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return subParser(startIndex..<index)
    }

    /// Read from buffer until we hit a character in supplied set. Position after this is of the character we were checking for
    /// - Parameter characterSet: Unicode.Scalar set to check against
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @discardableResult mutating func read(until characterSet: Set<Unicode.Scalar>, throwOnOverflow: Bool = true) throws -> Parser {
        let startIndex = index
        while !reachedEnd() {
            if characterSet.contains(unsafeCurrent()) {
                return subParser(startIndex..<index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return subParser(startIndex..<index)
    }

    /// Read from buffer until we hit a character in supplied set. Position after this is of the character we were checking for
    /// - Parameter characterSet: Unicode.Scalar set to check against
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @discardableResult mutating func read(until: (Unicode.Scalar) -> Bool, throwOnOverflow: Bool = true) throws -> Parser {
        let startIndex = index
        while !reachedEnd() {
            if until(unsafeCurrent()) {
                return subParser(startIndex..<index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return subParser(startIndex..<index)
    }

    /// Read from buffer until we hit a string. By default the position after this is of the beginning of the string we were checking for
    /// - Parameter untilString: String to check for
    /// - Parameter throwOnOverflow: Throw errors if we hit the end of the buffer
    /// - Parameter skipToEnd: Should we set the position to after the found string
    /// - Throws: .overflow, .emptyString
    /// - Returns: String read from buffer
    @discardableResult mutating func read(untilString: String, throwOnOverflow: Bool = true, skipToEnd: Bool = false) throws -> Parser {
        var untilString = untilString
        return try untilString.withUTF8 { utf8 in
            guard utf8.count > 0 else { throw Error.emptyString }
            let startIndex = index
            var foundIndex = index
            var untilIndex = 0
            while !reachedEnd() {
                if buffer[index] == utf8[untilIndex] {
                    if untilIndex == 0 {
                        foundIndex = index
                    }
                    untilIndex += 1
                    if untilIndex == utf8.endIndex {
                        unsafeAdvance()
                        if skipToEnd == false {
                            index = foundIndex
                        }
                        let result = subParser(startIndex..<foundIndex)
                        return result
                    }
                } else {
                    untilIndex = 0
                }
                index += 1
            }
            if throwOnOverflow {
                _setPosition(startIndex)
                throw Error.overflow
            }
            return subParser(startIndex..<index)
        }
    }

    /// Read from buffer from current position until the end of the buffer
    /// - Returns: String read from buffer
    @discardableResult mutating func readUntilTheEnd() -> Parser {
        let startIndex = index
        index = range.endIndex
        return subParser(startIndex..<index)
    }

    /// Read while character at current position is the one supplied
    /// - Parameter while: Unicode.Scalar to check against
    /// - Returns: String read from buffer
    @discardableResult mutating func read(while: Unicode.Scalar) -> Int {
        var count = 0
        while !reachedEnd(),
            unsafeCurrent() == `while` {
            unsafeAdvance()
            count += 1
        }
        return count
    }

    /// Read while character at current position is in supplied set
    /// - Parameter while: character set to check
    /// - Returns: String read from buffer
    @discardableResult mutating func read(while characterSet: Set<Unicode.Scalar>) -> Parser {
        let startIndex = index
        while !reachedEnd(),
            characterSet.contains(unsafeCurrent()) {
            unsafeAdvance()
        }
        return subParser(startIndex..<index)
    }

    /// Read while character at current position is in supplied set
    /// - Parameter while: character set to check
    /// - Returns: String read from buffer
    @discardableResult mutating func read(while: (Unicode.Scalar) -> Bool) -> Parser {
        let startIndex = index
        while !reachedEnd(),
            `while`(unsafeCurrent()) {
            unsafeAdvance()
        }
        return subParser(startIndex..<index)
    }

    /// Split parser into sections separated by character
    /// - Parameter separator: Separator character
    /// - Returns: arrays of sub parsers
    mutating func split(separator: Unicode.Scalar) -> [Parser] {
        var subParsers: [Parser] = []
        while !reachedEnd() {
            do {
                let section = try read(until: separator)
                subParsers.append(section)
                unsafeAdvance()
            } catch {
                if !reachedEnd() {
                    subParsers.append(readUntilTheEnd())
                }
            }
        }
        return subParsers
    }

    /// Return whether we have reached the end of the buffer
    /// - Returns: Have we reached the end
    func reachedEnd() -> Bool {
        return index == range.endIndex
    }
}

/// Public versions of internal functions which include tests for overflow
public extension Parser {
    /// Return the character at the current position
    /// - Throws: .overflow
    /// - Returns: Unicode.Scalar
    func current() -> Unicode.Scalar {
        guard !reachedEnd() else { return Unicode.Scalar(0) }
        return unsafeCurrent()
    }

    /// Move forward one character
    /// - Throws: .overflow
    mutating func advance() throws {
        guard !reachedEnd() else { throw Error.overflow }
        return unsafeAdvance()
    }

    /// Move forward so many character
    /// - Parameter amount: number of characters to move forward
    /// - Throws: .overflow
    mutating func advance(by amount: Int) throws {
        var amount = amount
        while amount > 0 {
            guard !reachedEnd() else { throw Error.overflow }
            index = skipUTF8Character(at: index)
            amount -= 1
        }
    }

    /// Move backwards one character
    /// - Throws: .overflow
    mutating func retreat() throws {
        guard index > range.startIndex else { throw Error.overflow }
        index = backOneUTF8Character(at: index)
    }

    /// Move back so many characters
    /// - Parameter amount: number of characters to move back
    /// - Throws: .overflow
    mutating func retreat(by amount: Int) throws {
        var amount = amount
        while amount > 0 {
            guard index > range.startIndex else { throw Error.overflow }
            index = backOneUTF8Character(at: index)
            amount -= 1
        }
    }

    mutating func unsafeAdvance() {
        index = skipUTF8Character(at: index)
    }

    mutating func unsafeAdvance(by amount: Int) {
        var amount = amount
        while amount > 0 {
            index = skipUTF8Character(at: index)
            amount -= 1
        }
    }
}

/// extend Parser to conform to Sequence
extension Parser: Sequence {
    public typealias Element = Unicode.Scalar

    public __consuming func makeIterator() -> Iterator {
        return Iterator(self)
    }


    public struct Iterator: IteratorProtocol {
        public typealias Element = Unicode.Scalar

        var parser: Parser

        init(_ parser: Parser) {
            self.parser = parser
        }

        public mutating func next() -> Unicode.Scalar? {
            guard !parser.reachedEnd() else { return nil }
            return parser.unsafeCurrentAndAdvance()
        }
    }
}

// internal versions without checks
private extension Parser {

    func unsafeCurrent() -> Unicode.Scalar {
        return decodeUTF8Character(at: index).0
    }

    mutating func unsafeCurrentAndAdvance() -> Unicode.Scalar {
        let (unicodeScalar, index) = decodeUTF8Character(at: self.index)
        self.index = index
        return unicodeScalar
    }

    mutating func _setPosition(_ index: Int) {
        self.index = index
    }

    func makeString<Bytes: Collection>(_ bytes: Bytes) -> String where Bytes.Element == UInt8, Bytes.Index == Int {
        if let string = bytes.withContiguousStorageIfAvailable({ String(decoding: $0, as: Unicode.UTF8.self)}) {
          return string
        }
        else {
          return String(decoding: bytes, as: Unicode.UTF8.self)
        }
    }
}

// UTF8 parsing
extension Parser {

    func decodeUTF8Character(at index: Int) -> (Unicode.Scalar, Int) {
        var index = index
        let byte1 = UInt32(buffer[index])
        var value: UInt32
        if byte1 & 0xc0 == 0xc0 {
            index += 1
            let byte2 = UInt32(buffer[index] & 0x3f)
            if byte1 & 0xe0 == 0xe0 {
                index += 1
                let byte3 = UInt32(buffer[index] & 0x3f)
                if byte1 & 0xf0 == 0xf0 {
                    index += 1
                    let byte4 = UInt32(buffer[index] & 0x3f)
                    value = (byte1 & 0x7) << 18 + byte2 << 12 + byte3 << 6 + byte4
                } else {
                    value = (byte1 & 0xf) << 12 + byte2 << 6 + byte3
                }
            } else {
                value = (byte1 & 0x1f) << 6 + byte2
            }
        } else {
            value = byte1 & 0x7f
        }
        let unicodeScalar = Unicode.Scalar(value)!
        return (unicodeScalar, index + 1)
    }

    func skipUTF8Character(at index: Int) -> Int {
        if buffer[index] & 0x80 != 0x80 { return index + 1 }
        if buffer[index+1] & 0xc0 == 0x80 { return index + 2 }
        if buffer[index+2] & 0xc0 == 0x80 { return index + 3 }
        return index + 4
    }

    func backOneUTF8Character(at index: Int) -> Int {
        if buffer[index-1] & 0xc0 != 0x80 { return index - 1 }
        if buffer[index-2] & 0xc0 != 0x80 { return index - 2 }
        if buffer[index-3] & 0xc0 != 0x80 { return index - 3 }
        return index - 4
    }

    /// same as `decodeUTF8Character` but adds extra validation, so we can make assumptions later on in decode and skip
    func validateUTF8Character(at index: Int) -> (Unicode.Scalar?, Int) {
        var index = index
        let byte1 = UInt32(buffer[index])
        var value: UInt32
        if byte1 & 0xc0 == 0xc0 {
            index += 1
            let byte = UInt32(buffer[index])
            guard byte & 0xc0 == 0x80 else { return (nil, index) }
            let byte2 = UInt32(byte & 0x3f)
            if byte1 & 0xe0 == 0xe0 {
                index += 1
                let byte = UInt32(buffer[index])
                guard byte & 0xc0 == 0x80 else { return (nil, index) }
                let byte3 = UInt32(byte & 0x3f)
                if byte1 & 0xf0 == 0xf0 {
                    index += 1
                    let byte = UInt32(buffer[index])
                    guard byte & 0xc0 == 0x80 else { return (nil, index) }
                    let byte4 = UInt32(byte & 0x3f)
                    value = (byte1 & 0x7) << 18 + byte2 << 12 + byte3 << 6 + byte4
                } else {
                    value = (byte1 & 0xf) << 12 + byte2 << 6 + byte3
                }
            } else {
                value = (byte1 & 0x1f) << 6 + byte2
            }
        } else {
            value = byte1 & 0x7f
        }
        let unicodeScalar = Unicode.Scalar(value)
        return (unicodeScalar, index + 1)
    }

    /// return if the buffer is valid UTF8
    func validateUTF8() -> Bool {
        var index = range.startIndex
        while index < range.endIndex {
            let (scalar, newIndex) = validateUTF8Character(at: index)
            guard scalar != nil else { return false }
            index = newIndex
        }
        return true
    }

    private static let asciiHexValues: [UInt8] = [
        /* 00 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 08 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 10 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 18 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 20 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 28 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 30 */  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        /* 38 */  0x08, 0x09, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 40 */  0x80, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x80,
        /* 48 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 50 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 58 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 60 */  0x80, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x80,
        /* 68 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 70 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 78 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,

        /* 80 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 88 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 90 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* 98 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* A0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* A8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* B0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* B8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* C0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* C8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* D0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* D8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* E0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* E8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* F0 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
        /* F8 */  0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
    ]

    /// percent decode UTF8
    public func percentDecode() -> String? {
        struct DecodeError: Swift.Error {}
        func _percentDecode(_ original: ArraySlice<UInt8>, _ bytes: UnsafeMutableBufferPointer<UInt8>) throws -> Int {
            var newIndex = 0
            var index = original.startIndex

            while index < original.endIndex {
                // if we have found a percent sign
                if original[index] == 0x25 {
                    let high = Self.asciiHexValues[Int(original[index+1])]
                    let low = Self.asciiHexValues[Int(original[index+2])]
                    index += 3
                    if ((high | low) & 0x80) != 0 {
                        throw DecodeError()
                    }
                    bytes[newIndex] = (high << 4) | low
                    newIndex += 1
                } else {
                    bytes[newIndex] = original[index]
                    newIndex += 1
                    index += 1
                }
            }
            return newIndex
        }

        guard index != range.endIndex else { return "" }
        do {
            if #available(macOS 11, *) {
                return try String(unsafeUninitializedCapacity: range.endIndex - index) { bytes -> Int in
                    return try _percentDecode(self.buffer[self.index..<range.endIndex], bytes)
                }
            } else {
                let newBuffer = try [UInt8].init(unsafeUninitializedCapacity: range.endIndex - index) { bytes, count in
                    try count = _percentDecode(self.buffer[self.index..<range.endIndex], bytes)
                }
                return makeString(newBuffer)
            }
        } catch {
            return nil
        }
    }
}

extension Unicode.Scalar {
    public var isWhitespace: Bool {
        return properties.isWhitespace
    }

    public var isNewline: Bool {
        switch self.value {
          case 0x000A...0x000D /* LF ... CR */: return true
          case 0x0085 /* NEXT LINE (NEL) */: return true
          case 0x2028 /* LINE SEPARATOR */: return true
          case 0x2029 /* PARAGRAPH SEPARATOR */: return true
          default: return false
        }
    }

    public var isNumber: Bool {
        return properties.numericType != nil
    }

    public var isLetter: Bool {
        return properties.isAlphabetic
    }
}

extension Set where Element == Unicode.Scalar {
    public init(_ string: String) {
        self = Set(string.unicodeScalars)
    }
}
