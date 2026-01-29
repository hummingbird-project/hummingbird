//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

@available(macOS 26, *)
package struct SpanParser: ~Escapable, ~Copyable {
    package enum Error: Swift.Error {
        case overflow
        case unexpected
        case emptyString
        case invalidUTF8
    }

    private let span: Span<UInt8>
    private var index: Int
    private let range: Range<Int>

    @_lifetime(copy span)
    package init(_ span: Span<UInt8>) {
        self.span = span
        self.index = 0
        self.range = 0..<span.count
    }

    @_lifetime(borrow string)
    package init(_ string: borrowing String) {
        self.span = string.utf8Span.span
        self.index = 0
        self.range = 0..<span.count
    }

    @_lifetime(borrow parser)
    private init(_ parser: borrowing SpanParser, range: Range<Int>) {
        self.span = parser.span
        self.index = 0
        self.range = range
    }

    /// Return contents of parser as a string
    package var string: String {
        String(copying: UTF8Span(unchecked: self.span))
    }

    package var count: Int {
        range.count
    }

    @_lifetime(borrow self)
    package func subParser(_ range: Range<Int>) -> SpanParser {
        .init(self, range: range)
    }
}

@available(macOS 26, *)
extension SpanParser {
    /// Return whether we have reached the end of the buffer
    /// - Returns: Have we reached the end
    package func reachedEnd() -> Bool {
        self.index == self.range.endIndex
    }
    /// Return current character
    /// - Throws: .overflow
    /// - Returns: Current character
    package mutating func character() throws -> Unicode.Scalar {
        guard !self.reachedEnd() else { throw Error.overflow }
        return unsafeCurrentAndAdvance()
    }

    /// Read the current character and return if it is as intended. If character test returns true then move forward 1
    /// - Parameter char: character to compare against
    /// - Throws: .overflow
    /// - Returns: If current character was the one we expected
    @_lifetime(&self)
    package mutating func read(_ char: Unicode.Scalar) throws -> Bool {
        let initialIndex = self.index
        let c = try character()
        guard c == char else {
            self.index = initialIndex
            return false
        }
        return true
    }

    /// Read the current character and check if it is in a set of characters If character test returns true then move forward 1
    /// - Parameter characterSet: Set of characters to compare against
    /// - Throws: .overflow
    /// - Returns: If current character is in character set
    @_lifetime(&self)
    package mutating func read(_ characterSet: Set<Unicode.Scalar>) throws -> Bool {
        let initialIndex = self.index
        let c = try character()
        guard characterSet.contains(c) else {
            self.index = initialIndex
            return false
        }
        return true
    }

    /// Compare characters at current position against provided string. If the characters are the same as string provided advance past string
    /// - Parameter string: String to compare against
    /// - Throws: .overflow, .emptyString
    /// - Returns: If characters at current position equal string
    @_lifetime(&self)
    package mutating func read(_ string: String) throws -> Bool {
        let initialIndex = self.index
        guard string.count > 0 else { throw Error.emptyString }
        let subString = try read(count: string.count)
        guard subString.string == string else {
            self.index = initialIndex
            return false
        }
        return true
    }

    /// Read next so many characters from buffer
    /// - Parameter count: Number of characters to read
    /// - Throws: .overflow
    /// - Returns: The string read from the buffer
    @_lifetime(&self)
    @discardableResult
    package mutating func read(count: Int) throws -> SpanParser {
        var count = count
        var readEndIndex = self.index
        while count > 0 {
            guard readEndIndex != self.range.endIndex else { throw Error.overflow }
            readEndIndex = skipUTF8Character(at: readEndIndex)
            count -= 1
        }
        let index = self.index
        self.index = readEndIndex
        let result = self.subParser(index..<readEndIndex)
        return result
    }

    /// Read from buffer until we hit a character. Position after this is of the character we were checking for
    /// - Parameter until: Unicode.Scalar to read until
    /// - Throws: .overflow if we hit the end of the buffer before reading character
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult
    package mutating func read(until: Unicode.Scalar, throwOnOverflow: Bool = true) throws -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd() {
            if unsafeCurrent() == until {
                return self.subParser(startIndex..<self.index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read from buffer until we hit a character in supplied set. Position after this is of the character we were checking for
    /// - Parameter characterSet: Unicode.Scalar set to check against
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult
    package mutating func read(until characterSet: Set<Unicode.Scalar>, throwOnOverflow: Bool = true) throws -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd() {
            if characterSet.contains(unsafeCurrent()) {
                return self.subParser(startIndex..<self.index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read from buffer until we hit a character that returns true for supplied closure. Position after this is of the character we were checking for
    /// - Parameter until: Function to test
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(until: (Unicode.Scalar) -> Bool, throwOnOverflow: Bool = true) throws -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd() {
            if until(unsafeCurrent()) {
                return self.subParser(startIndex..<self.index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read from buffer until we hit a character where supplied KeyPath is true. Position after this is of the character we were checking for
    /// - Parameter characterSet: Unicode.Scalar set to check against
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(until keyPath: KeyPath<Unicode.Scalar, Bool>, throwOnOverflow: Bool = true) throws -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd() {
            if unsafeCurrent()[keyPath: keyPath] {
                return self.subParser(startIndex..<self.index)
            }
            unsafeAdvance()
        }
        if throwOnOverflow {
            _setPosition(startIndex)
            throw Error.overflow
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read from buffer until we hit a string. By default the position after this is of the beginning of the string we were checking for
    /// - Parameter untilString: String to check for
    /// - Parameter throwOnOverflow: Throw errors if we hit the end of the buffer
    /// - Parameter skipToEnd: Should we set the position to after the found string
    /// - Throws: .overflow, .emptyString
    /// - Returns: String read from buffer
    /*@_lifetime(&self)
    @discardableResult package mutating func read(untilString: String, throwOnOverflow: Bool = true, skipToEnd: Bool = false) throws -> SpanParser {
        var untilString = untilString
        return try untilString.withUTF8 { utf8 in
            guard utf8.count > 0 else { throw Error.emptyString }
            let startIndex = self.index
            var foundIndex = self.index
            var untilIndex = 0
            while !self.reachedEnd() {
                if self.buffer[self.index] == utf8[untilIndex] {
                    if untilIndex == 0 {
                        foundIndex = self.index
                    }
                    untilIndex += 1
                    if untilIndex == utf8.endIndex {
                        unsafeAdvance()
                        if skipToEnd == false {
                            self.index = foundIndex
                        }
                        let result = self.subParser(startIndex..<foundIndex)
                        return result
                    }
                } else {
                    untilIndex = 0
                }
                self.index += 1
            }
            if throwOnOverflow {
                _setPosition(startIndex)
                throw Error.overflow
            }
            return self.subParser(startIndex..<self.index)
        }
    }*/

    /// Read from buffer from current position until the end of the buffer
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func readUntilTheEnd() -> SpanParser {
        let startIndex = self.index
        self.index = self.range.endIndex
        return self.subParser(startIndex..<self.index)
    }

    /// Read while character at current position is the one supplied
    /// - Parameter while: Unicode.Scalar to check against
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(while: Unicode.Scalar) -> Int {
        var count = 0
        while !self.reachedEnd(),
            unsafeCurrent() == `while`
        {
            unsafeAdvance()
            count += 1
        }
        return count
    }

    /// Read while character at current position is in supplied set
    /// - Parameter while: character set to check
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(while characterSet: Set<Unicode.Scalar>) -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd(),
            characterSet.contains(unsafeCurrent())
        {
            unsafeAdvance()
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read while character returns true for supplied closure
    /// - Parameter while: character set to check
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(while: (Unicode.Scalar) -> Bool) -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd(),
            `while`(unsafeCurrent())
        {
            unsafeAdvance()
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Read while character returns true for supplied KeyPath
    /// - Parameter while: character set to check
    /// - Returns: String read from buffer
    @_lifetime(&self)
    @discardableResult package mutating func read(while keyPath: KeyPath<Unicode.Scalar, Bool>) -> SpanParser {
        let startIndex = self.index
        while !self.reachedEnd(),
            unsafeCurrent()[keyPath: keyPath]
        {
            unsafeAdvance()
        }
        return self.subParser(startIndex..<self.index)
    }

    /// Return the character at the current position
    /// - Throws: .overflow
    /// - Returns: Unicode.Scalar
    package func current() -> Unicode.Scalar {
        guard !self.reachedEnd() else { return Unicode.Scalar(0) }
        return unsafeCurrent()
    }

    /// Move forward one character
    /// - Throws: .overflow
    package mutating func advance() throws {
        guard !self.reachedEnd() else { throw Error.overflow }
        return self.unsafeAdvance()
    }

    /// Move forward so many character
    /// - Parameter amount: number of characters to move forward
    /// - Throws: .overflow
    @_lifetime(&self)
    package mutating func advance(by amount: Int) throws {
        var amount = amount
        while amount > 0 {
            guard !self.reachedEnd() else { throw Error.overflow }
            self.index = skipUTF8Character(at: self.index)
            amount -= 1
        }
    }

    /// Move backwards one character
    /// - Throws: .overflow
    package mutating func retreat() throws {
        guard self.index > self.range.startIndex else { throw Error.overflow }
        self.index = backOneUTF8Character(at: self.index)
    }

    /// Move back so many characters
    /// - Parameter amount: number of characters to move back
    /// - Throws: .overflow
    @_lifetime(&self)
    package mutating func retreat(by amount: Int) throws {
        var amount = amount
        while amount > 0 {
            guard self.index > self.range.startIndex else { throw Error.overflow }
            self.index = backOneUTF8Character(at: self.index)
            amount -= 1
        }
    }

    /// Move parser to beginning of string
    package mutating func moveToStart() {
        self.index = self.range.startIndex
    }

    /// Move parser to end of string
    package mutating func moveToEnd() {
        self.index = self.range.endIndex
    }
}

@available(macOS 26, *)
extension SpanParser {
    package mutating func unsafeAdvance() {
        self.index = skipUTF8Character(at: self.index)
    }

    @_lifetime(&self)
    package mutating func unsafeAdvance(by amount: Int) {
        var amount = amount
        while amount > 0 {
            self.index = skipUTF8Character(at: self.index)
            amount -= 1
        }
    }

    fileprivate func unsafeCurrent() -> Unicode.Scalar {
        decodeUTF8Character(at: self.index).0
    }

    fileprivate mutating func unsafeCurrentAndAdvance() -> Unicode.Scalar {
        let (unicodeScalar, index) = decodeUTF8Character(at: self.index)
        self.index = index
        return unicodeScalar
    }

    @_lifetime(&self)
    fileprivate mutating func _setPosition(_ index: Int) {
        self.index = index
    }
}

// UTF8 parsing
@available(macOS 26, *)
extension SpanParser {
    func decodeUTF8Character(at index: Int) -> (Unicode.Scalar, Int) {
        var index = index
        let byte1 = UInt32(span[index])
        var value: UInt32
        if byte1 & 0xC0 == 0xC0 {
            index += 1
            let byte2 = UInt32(span[index] & 0x3F)
            if byte1 & 0xE0 == 0xE0 {
                index += 1
                let byte3 = UInt32(span[index] & 0x3F)
                if byte1 & 0xF0 == 0xF0 {
                    index += 1
                    let byte4 = UInt32(span[index] & 0x3F)
                    value = (byte1 & 0x7) << 18 + byte2 << 12 + byte3 << 6 + byte4
                } else {
                    value = (byte1 & 0xF) << 12 + byte2 << 6 + byte3
                }
            } else {
                value = (byte1 & 0x1F) << 6 + byte2
            }
        } else {
            value = byte1 & 0x7F
        }
        let unicodeScalar = Unicode.Scalar(value)!
        return (unicodeScalar, index + 1)
    }

    func skipUTF8Character(at index: Int) -> Int {
        if self.span[index] & 0x80 != 0x80 { return index + 1 }
        if self.span[index + 1] & 0xC0 == 0x80 { return index + 2 }
        if self.span[index + 2] & 0xC0 == 0x80 { return index + 3 }
        return index + 4
    }

    func backOneUTF8Character(at index: Int) -> Int {
        if self.span[index - 1] & 0xC0 != 0x80 { return index - 1 }
        if self.span[index - 2] & 0xC0 != 0x80 { return index - 2 }
        if self.span[index - 3] & 0xC0 != 0x80 { return index - 3 }
        return index - 4
    }

    /// same as `decodeUTF8Character` but adds extra validation, so we can make assumptions later on in decode and skip
    func validateUTF8Character(at index: Int) -> (Unicode.Scalar?, Int) {
        var index = index
        let byte1 = UInt32(span[index])
        var value: UInt32
        if byte1 & 0xC0 == 0xC0 {
            index += 1
            let byte = UInt32(span[index])
            guard byte & 0xC0 == 0x80 else { return (nil, index) }
            let byte2 = UInt32(byte & 0x3F)
            if byte1 & 0xE0 == 0xE0 {
                index += 1
                let byte = UInt32(span[index])
                guard byte & 0xC0 == 0x80 else { return (nil, index) }
                let byte3 = UInt32(byte & 0x3F)
                if byte1 & 0xF0 == 0xF0 {
                    index += 1
                    let byte = UInt32(span[index])
                    guard byte & 0xC0 == 0x80 else { return (nil, index) }
                    let byte4 = UInt32(byte & 0x3F)
                    value = (byte1 & 0x7) << 18 + byte2 << 12 + byte3 << 6 + byte4
                } else {
                    value = (byte1 & 0xF) << 12 + byte2 << 6 + byte3
                }
            } else {
                value = (byte1 & 0x1F) << 6 + byte2
            }
        } else {
            value = byte1 & 0x7F
        }
        let unicodeScalar = Unicode.Scalar(value)
        return (unicodeScalar, index + 1)
    }

    /// return if the buffer is valid UTF8
    func validateUTF8() -> Bool {
        var index = self.range.startIndex
        while index < self.range.endIndex {
            let (scalar, newIndex) = self.validateUTF8Character(at: index)
            guard scalar != nil else { return false }
            index = newIndex
        }
        return true
    }
}
