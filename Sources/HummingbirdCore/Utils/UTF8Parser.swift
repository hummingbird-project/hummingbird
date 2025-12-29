//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2026 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if compiler(>=6.2)

/// Version of Parser that uses UTF8Span
@available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
package struct UTF8Parser: ~Escapable {
    @usableFromInline
    package enum Error: Swift.Error {
        case overflow
        case emptyString
    }

    @usableFromInline
    package var utf8Span: UTF8Span
    @usableFromInline
    var iterator: UTF8Span.UnicodeScalarIterator

    @inlinable
    @_lifetime(borrow utf8Span)
    package init(_ utf8Span: UTF8Span) {
        self.utf8Span = utf8Span
        self.iterator = utf8Span.makeUnicodeScalarIterator()
    }

    /// Return contents of parser as a string
    @inlinable
    package var string: String {
        String(copying: self.utf8Span)
    }
}

@available(macOS 26, iOS 26, tvOS 26, macCatalyst 26, visionOS 26, *)
extension UTF8Parser {
    /// Return current character
    /// - Throws: .overflow
    /// - Returns: Current character
    @inlinable
    package mutating func character() throws -> Unicode.Scalar {
        guard let c = self.iterator.next() else { throw Error.overflow }
        return c
    }

    /// Read the current character and return if it is as intended. If character test returns true then move forward 1
    /// - Parameter char: character to compare against
    /// - Throws: .overflow
    /// - Returns: If current character was the one we expected
    @inlinable
    @_lifetime(&self)
    package mutating func read(_ char: Unicode.Scalar) throws -> Bool {
        let current = self.iterator
        let c = try character()
        guard c == char else {
            self.iterator = current
            return false
        }
        return true
    }

    /// Read the current character and check if it is in a set of characters If character test returns true then move forward 1
    /// - Parameter characterSet: Set of characters to compare against
    /// - Throws: .overflow
    /// - Returns: If current character is in character set
    @inlinable
    @_lifetime(&self)
    package mutating func read(_ characterSet: Set<Unicode.Scalar>) throws -> Bool {
        let current = self.iterator
        let c = try character()
        guard characterSet.contains(c) else {
            self.iterator = current
            return false
        }
        return true
    }

    /// Compare characters at current position against provided string. If the characters are the same as string provided advance past string
    /// - Parameter string: String to compare against
    /// - Throws: .overflow, .emptyString
    /// - Returns: If characters at current position equal string
    @inlinable
    @_lifetime(&self)
    package mutating func read(_ string: String) throws -> Bool {
        let startIndex = self.iterator.currentCodeUnitOffset
        guard string.count > 0 else { throw Error.emptyString }
        var stringIterator = string.utf8Span.makeUnicodeScalarIterator()
        while let scalar = stringIterator.next() {
            if self.iterator.next() != scalar {
                self.iterator.reset(toUnchecked: startIndex)
                return false
            }
        }
        return true
    }

    /// Read next so many characters from buffer
    /// - Parameter count: Number of characters to read
    /// - Throws: .overflow
    /// - Returns: The string read from the buffer
    @inlinable
    @_lifetime(&self)
    package mutating func read(count: Int) throws -> UTF8Span {
        var count = count
        let startIndex = self.iterator.currentCodeUnitOffset
        while count > 0 {
            guard self.iterator.next() != nil else { throw Error.overflow }
            count -= 1
        }
        return self.subSpan(startIndex..<self.iterator.currentCodeUnitOffset)
    }

    /// Read from buffer until we hit a character. Position after this is of the character we were checking for
    /// - Parameter until: Unicode.Scalar to read until
    /// - Throws: .overflow if we hit the end of the buffer before reading character
    /// - Returns: String read from buffer
    @inlinable
    @_lifetime(&self)
    @discardableResult
    package mutating func read(until: Unicode.Scalar, throwOnOverflow: Bool = true) throws -> UTF8Span {
        let startIndex = self.iterator.currentCodeUnitOffset
        while let scalar = self.iterator.next() {
            if scalar == until {
                let bounds = startIndex..<self.iterator.currentCodeUnitOffset
                _ = self.iterator.previous()
                return self.subSpan(bounds)
            }
        }
        if throwOnOverflow {
            self.iterator.reset(toUnchecked: startIndex)
            throw Error.overflow
        }
        return self.subSpan(startIndex..<self.iterator.currentCodeUnitOffset)
    }

    /// Read from buffer until we hit a character in supplied set. Position after this is of the character we were checking for
    /// - Parameter characterSet: Unicode.Scalar set to check against
    /// - Throws: .overflow
    /// - Returns: String read from buffer
    @inlinable
    @_lifetime(&self)
    @discardableResult
    package mutating func read(until characterSet: Set<Unicode.Scalar>, throwOnOverflow: Bool = true) throws -> UTF8Span {
        let startIndex = self.iterator.currentCodeUnitOffset
        while let scalar = self.iterator.next() {
            if characterSet.contains(scalar) {
                let bounds = startIndex..<self.iterator.currentCodeUnitOffset
                _ = self.iterator.previous()
                return self.subSpan(bounds)
            }
        }
        if throwOnOverflow {
            self.iterator.reset(toUnchecked: startIndex)
            throw Error.overflow
        }
        return self.subSpan(startIndex..<self.iterator.currentCodeUnitOffset)
    }

    /// Read from buffer until we hit a string. By default the position after this is of the beginning of the string we were checking for
    /// - Parameter untilString: String to check for
    /// - Parameter throwOnOverflow: Throw errors if we hit the end of the buffer
    /// - Parameter skipToEnd: Should we set the position to after the found string
    /// - Throws: .overflow, .emptyString
    /// - Returns: String read from buffer
    @inlinable
    @_lifetime(&self)
    @discardableResult
    package mutating func read(untilString: String, throwOnOverflow: Bool = true, skipToEnd: Bool = false) throws -> UTF8Span {
        guard untilString.count > 0 else { throw Error.emptyString }
        var throwError = throwOnOverflow
        let stringUTF8Span = untilString.utf8Span
        let startIndex = self.iterator.currentCodeUnitOffset
        var foundIndex = self.iterator.currentCodeUnitOffset
        var untilIterator = stringUTF8Span.makeUnicodeScalarIterator()
        let untilStartIndex = untilIterator.currentCodeUnitOffset
        while let scalar = self.iterator.next() {
            if let untilScalar = untilIterator.next() {
                if scalar == untilScalar {
                    continue
                } else {
                    untilIterator.reset(toUnchecked: untilStartIndex)
                    foundIndex = self.iterator.currentCodeUnitOffset
                }
            } else {
                if !skipToEnd {
                    self.iterator.reset(toUnchecked: foundIndex)
                }
                throwError = false
                break
            }
        }
        if throwError {
            self.iterator.reset(toUnchecked: startIndex)
            throw Error.overflow
        }
        return self.subSpan(startIndex..<foundIndex)
    }

    @inlinable
    @_lifetime(borrow self)
    func subSpan(_ bounds: Range<Int>) -> UTF8Span {
        let subSpan = self.utf8Span.span.extracting(bounds)
        return .init(unchecked: subSpan)
    }
}
#endif
