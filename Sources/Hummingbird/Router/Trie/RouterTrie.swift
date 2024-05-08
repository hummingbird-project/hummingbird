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

enum TrieTokenKind: UInt8 {
    case null = 0
    case path, capture, prefixCapture, suffixCapture, wildcard, prefixWildcard, suffixWildcard, recursiveWildcard
    case deadEnd
}

struct TrieNode: Sendable {
    let valueIndex: UInt16
    let token: TrieTokenKind
    var nextSiblingNodeIndex: UInt16
    var constant: UInt16?
    var parameter: UInt16?
}

struct Trie: Sendable {
    var nodes = [TrieNode]()
    var parameters = [Substring]()
    var constants = [Substring]()
}

@_spi(Internal) public final class RouterTrie<Value: Sendable>: Sendable {
    let trie: Trie
    let values: [Value?]

    @_spi(Internal) public init(base: RouterPathTrieBuilder<Value>) {
        var trie = Trie()
        var values: [Value?] = []

        Self.serialize(
            base.root,
            trie: &trie,
            values: &values
        )

        trie.nodes.append(
            TrieNode(
                valueIndex: 0,
                token: .deadEnd,
                nextSiblingNodeIndex: .max
            )
        )

        self.trie = trie
        self.values = values
    }
}
