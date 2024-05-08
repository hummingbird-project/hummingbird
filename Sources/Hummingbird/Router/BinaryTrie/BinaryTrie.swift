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

@_spi(Internal) public final class BinaryTrie<Value: Sendable>: Sendable {
    @usableFromInline
    typealias Integer = UInt8

    @usableFromInline
    let trie: ByteBuffer

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

        self.trie = trie
        self.values = values
    }
}
