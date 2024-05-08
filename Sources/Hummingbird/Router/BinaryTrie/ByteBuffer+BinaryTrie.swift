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
    /// Write length prefixed string to ByteBuffer
    @inlinable
    mutating func writeLengthPrefixedString<F: FixedWidthInteger>(_ string: Substring, as integer: F.Type) {
        do {
            try self.writeLengthPrefixed(endianness: .host, as: F.self) { buffer in
                buffer.writeSubstring(string)
            }
        } catch {
            preconditionFailure("Failed to write \"\(string)\" into BinaryTrie")
        }
    }

    /// Write BinaryTrieNode into ByteBuffer at position
    @discardableResult mutating func setBinaryTrieNode(_ node: BinaryTrieNode, at index: Int) -> Int {
        var offset = self.setInteger(node.index, at: index, endianness: .host)
        offset += self.setInteger(node.token.rawValue, at: index + offset, endianness: .host)
        offset += self.setInteger(node.nextSiblingNodeIndex, at: index + offset, endianness: .host)
        return offset
    }

    /// Write BinaryTrieNode into ByteBuffer at position
    mutating func writeBinaryTrieNode(_ node: BinaryTrieNode) {
        let offset = self.setBinaryTrieNode(node, at: self.writerIndex)
        self.moveWriterIndex(forwardBy: offset)
    }

    /// Reserve space for a BinaryTrieNode
    mutating func reserveBinaryTrieNode() {
        self.moveWriterIndex(forwardBy: BinaryTrieNode.serializedSize)
    }
}

extension Trie.ParsingContext {
    /// Read BinaryTrieNode from ByteBuffer
    @usableFromInline
    mutating func readBinaryTrieNode() -> BinaryTrieNode {
        let index = buffer.loadUnaligned(fromByteOffset: byteOffset, as: UInt16.self)
        byteOffset &+= 2

        let token = buffer.loadUnaligned(fromByteOffset: byteOffset, as: BinaryTrieTokenKind.self)
        byteOffset &+= 1

        let nextSiblingNodeIndex = buffer.loadUnaligned(fromByteOffset: byteOffset, as: UInt32.self)
        byteOffset &+= 4

        return BinaryTrieNode(index: index, token: token, nextSiblingNodeIndex: nextSiblingNodeIndex)
    }

    /// Read string from ByteBuffer and compare against another string
    @inlinable
    mutating func readAndCompareString<Length: FixedWidthInteger>(
        to string: Substring,
        length: Length.Type
    ) -> Bool {
        let length = Int(buffer.loadUnaligned(fromByteOffset: byteOffset, as: Length.self))
        byteOffset &+= Length.bitWidth / 8

        func compare(utf8: UnsafeBufferPointer<UInt8>) -> Bool {
            if utf8.count != length {
                return false
            }

            if length == 0 {
                // Needed, because `memcmp` wants a non-null pointer on Linux
                // and a zero-length buffer has no baseAddress
                return true
            }

            if memcmp(
                utf8.baseAddress!,
                buffer.baseAddress!.advanced(by: byteOffset),
                length
            ) == 0 {
                byteOffset &+= length
                return true
            } else {
                return false
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
    @inlinable
    mutating func readLengthPrefixedString<F: FixedWidthInteger>(
        as integer: F.Type
    ) -> String? {
        let lengthPrefix = buffer.loadUnaligned(fromByteOffset: byteOffset, as: F.self)
        byteOffset &+= (F.bitWidth / 8)
        let string = String(
            bytes: UnsafeRawBufferPointer(
                start: buffer.baseAddress!.advanced(
                    by: byteOffset
                ),
                count: Int(lengthPrefix)
            ),
            encoding: .utf8
        )
        byteOffset &+= Int(lengthPrefix)
        return string
    }
}
