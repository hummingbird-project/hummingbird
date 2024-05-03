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

enum BinaryTrieTokenKind: UInt8 {
    case null = 0
    case path, capture, prefixCapture, suffixCapture, wildcard, prefixWildcard, suffixWildcard, recursiveWildcard
    case deadEnd
}

@_spi(Internal) public final class BinaryTrie<Value: Sendable>: Sendable {
    typealias Integer = UInt8
    let trie: ByteBuffer
    let values: [Value?]

    @_spi(Internal) public init(base: RouterPathTrieBuilder<Value>) {
        var trie = ByteBufferAllocator().buffer(capacity: 1024)
        var values = [base.root.value]

        Self.serializeChildren(
            of: base.root,
            trie: &trie,
            values: &values
        )

        self.trie = trie
        self.values = values
    }
}
