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

@usableFromInline
enum BinaryTrieTokenKind: UInt8 {
    case null = 0
    case path, capture, prefixCapture, suffixCapture, wildcard, prefixWildcard, suffixWildcard, recursiveWildcard
    case deadEnd
}

@usableFromInline
struct BinaryTrieNode {
    @usableFromInline
    let index: UInt16

    @usableFromInline
    let token: BinaryTrieTokenKind

    @usableFromInline
    let nextSiblingNodeIndex: UInt32

    /// How many bytes a serialized BinaryTrieNode uses
    static let serializedSize = 7
}

@usableFromInline
struct Trie: @unchecked Sendable {
    @usableFromInline
    let trie: ManagedBuffer<Void, UInt8>

    @inlinable
    init(trie: ManagedBuffer<Void, UInt8>) {
        self.trie = trie
    }

    @usableFromInline
    func withParsingContext<T>(
        _ perform: (inout ParsingContext) throws -> T
    ) rethrows -> T {
        let byteSize = trie.capacity
        return try trie.withUnsafeMutablePointerToElements { pointer in
            var context = ParsingContext(
                buffer: UnsafeRawBufferPointer(
                    start: pointer,
                    count: byteSize
                ),
                byteOffset: 0
            )

            return try perform(&context)
        }
    }

    @usableFromInline
    struct ParsingContext {
        @usableFromInline
        let buffer: UnsafeRawBufferPointer

        @usableFromInline
        var byteOffset: Int

        @usableFromInline
        init(buffer: UnsafeRawBufferPointer, byteOffset: Int) {
            self.buffer = buffer
            self.byteOffset = byteOffset
        }

        @usableFromInline
        var isAtEnd: Bool {
            byteOffset >= buffer.count
        }
    }
}

@_spi(Internal) public final class BinaryTrie<Value: Sendable>: Sendable {
    @usableFromInline
    typealias Integer = UInt8

    @usableFromInline
    let trie: Trie

    @usableFromInline
    let values: [Value?]

    @inlinable
    @_spi(Internal) public init(base: RouterPathTrieBuilder<Value>) {
        var trie = ByteBufferAllocator().buffer(capacity: 1024)
        var values: [Value?] = []

        Self.serialize(
            base.root,
            trie: &trie,
            values: &values
        )

        let buffer = ManagedBuffer<Void, UInt8>.create(
            minimumCapacity: trie.readableBytes
        ) { managedBuffer in
            return ()
        }
        
        buffer.withUnsafeMutablePointerToElements { destination in
            trie.withUnsafeReadableBytes { source in
                _ = source.copyBytes(
                    to: UnsafeMutableRawBufferPointer(
                        start: destination,
                        count: source.count
                    )
                )
            }
        }

        self.trie = Trie(trie: buffer)
        self.values = values
    }
}
