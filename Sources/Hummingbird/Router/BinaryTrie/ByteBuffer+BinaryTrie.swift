//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Musl)
import Musl
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
#error("unsupported os")
#endif

internal extension ByteBuffer {
    /// Write BinaryTrieTokenKind to ByteBuffer
    mutating func writeToken(_ token: BinaryTrieTokenKind) {
        writeInteger(token.rawValue)
    }

    /// Write length prefixed string to ByteBuffer
    mutating func writeLengthPrefixedString<F: FixedWidthInteger>(_ string: Substring, as integer: F.Type) {
        do {
            try self.writeLengthPrefixed(as: F.self) { buffer in
                buffer.writeSubstring(string)
            }
        } catch {
            preconditionFailure("Failed to write \"\(string)\" into BinaryTrie")
        }
    }

    /// Read string from ByteBuffer and compare against another string
    mutating func readAndCompareString<Length: FixedWidthInteger>(
        to string: Substring,
        length: Length.Type
    ) -> Bool {
        guard
            let _length: Length = readInteger()
        else {
            return false
        }

        let length = Int(_length)

        func compare(utf8: UnsafeBufferPointer<UInt8>) -> Bool {
            if utf8.count != length {
                return false
            }

            if length == 0 {
                // Needed, because `memcmp` wants a non-null pointer on Linux
                // and a zero-length buffer has no baseAddress
                return true
            }

            return withUnsafeReadableBytes { buffer in
                if memcmp(utf8.baseAddress!, buffer.baseAddress!, length) == 0 {
                    moveReaderIndex(forwardBy: length)
                    return true
                } else {
                    return false
                }
            }
        }

        guard let result = string.withContiguousStorageIfAvailable({ characters in
            characters.withMemoryRebound(to: UInt8.self) { utf8 in
                compare(utf8: utf8)
            }
        }) else {
            var string = string
            return string.withUTF8 { utf8 in
                compare(utf8: utf8)
            }
        }

        return result
    }

    /// Read length prefixed string from ByteBuffer
    mutating func readLengthPrefixedString<F: FixedWidthInteger>(as integer: F.Type) -> String? {
        guard let buffer = readLengthPrefixedSlice(as: F.self) else {
            return nil
        }

        return String(buffer: buffer)
    }

    /// Read BinaryTrieTokenKind from ByteBuffer
    mutating func readToken() -> BinaryTrieTokenKind? {
        guard
            let _token: BinaryTrieTokenKind.RawValue = readInteger(),
            let token = BinaryTrieTokenKind(rawValue: _token)
        else {
            return nil
        }

        return token
    }
}
