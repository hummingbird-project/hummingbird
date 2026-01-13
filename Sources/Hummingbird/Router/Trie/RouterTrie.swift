//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

@usableFromInline
enum TrieToken: Equatable, Sendable {
    case null
    case path(constantIndex: UInt32)
    case capture(parameterIndex: UInt32)
    case prefixCapture(parameterIndex: UInt32, suffixIndex: UInt32)
    case suffixCapture(prefixIndex: UInt32, parameterIndex: UInt32)
    case prefixWildcard(suffixIndex: UInt32)
    case suffixWildcard(prefixIndex: UInt32)
    case wildcard, recursiveWildcard
    case deadEnd
}

@usableFromInline
struct TrieNode: Sendable {
    @usableFromInline
    let valueIndex: Int

    @usableFromInline
    let token: TrieToken

    @usableFromInline
    var nextSiblingNodeIndex: Int

    @usableFromInline
    init(valueIndex: Int, token: TrieToken, nextSiblingNodeIndex: Int) {
        self.valueIndex = valueIndex
        self.token = token
        self.nextSiblingNodeIndex = nextSiblingNodeIndex
    }
}

@usableFromInline
struct Trie: Sendable {
    @usableFromInline
    var nodes = [TrieNode]()

    @usableFromInline
    var stringValues = [Substring]()

    @usableFromInline
    init() {}
}

@_documentation(visibility: internal)
public final class RouterTrie<Value: Sendable>: Sendable {
    @usableFromInline
    let trie: Trie

    @usableFromInline
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
