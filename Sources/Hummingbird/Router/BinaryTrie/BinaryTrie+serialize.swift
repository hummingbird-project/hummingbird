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

import NIOCore

extension BinaryTrie {
    static func serialize(
        _ node: RouterPathTrieBuilder<Value>.Node,
        trie: inout ByteBuffer,
        values: inout [Value?]
    ) {
        let binaryTrieNodeIndex = trie.writerIndex
        trie.reserveBinaryTrieNode()
        // Index where `value` is located
        let index = UInt16(values.count)
        values.append(node.value)

        let token: BinaryTrieTokenKind
        switch node.key {
        case .path(let path):
            token = .path
            // Serialize the path constant
            trie.writeLengthPrefixedString(path, as: Integer.self)
        case .capture(let parameter):
            token = .capture
            // Serialize the parameter
            trie.writeLengthPrefixedString(parameter, as: Integer.self)
        case .prefixCapture(suffix: let suffix, parameter: let parameter):
            token = .prefixCapture
            // Serialize the suffix and parameter
            trie.writeLengthPrefixedString(suffix, as: Integer.self)
            trie.writeLengthPrefixedString(parameter, as: Integer.self)
        case .suffixCapture(prefix: let prefix, parameter: let parameter):
            token = .suffixCapture
            // Serialize the prefix and parameter
            trie.writeLengthPrefixedString(prefix, as: Integer.self)
            trie.writeLengthPrefixedString(parameter, as: Integer.self)
        case .wildcard:
            token = .wildcard
        case .prefixWildcard(let suffix):
            token = .prefixWildcard
            // Serialize the suffix
            trie.writeLengthPrefixedString(suffix, as: Integer.self)
        case .suffixWildcard(let prefix):
            token = .suffixWildcard
            // Serialize the prefix
            trie.writeLengthPrefixedString(prefix, as: Integer.self)
        case .recursiveWildcard:
            token = .recursiveWildcard
        case .null:
            token = .null
        }

        self.serializeChildren(
            of: node,
            trie: &trie,
            values: &values
        )

        let deadEndIndex = trie.writerIndex
        // The last node in a trie is always a deadEnd token. We reserve space for it so we
        // get the correct writer index for the next sibling
        trie.reserveBinaryTrieNode()
        trie.setBinaryTrieNode(.init(index: 0, token: .deadEnd, nextSiblingNodeIndex: UInt32(trie.writerIndex)), at: deadEndIndex)
        // Write trie node
        trie.setBinaryTrieNode(.init(index: index, token: token, nextSiblingNodeIndex: UInt32(trie.writerIndex)), at: binaryTrieNodeIndex)
    }

    static func serializeChildren(
        of node: RouterPathTrieBuilder<Value>.Node,
        trie: inout ByteBuffer,
        values: inout [Value?]
    ) {
        // Serialize the child nodes in order of priority
        // That's also the order of resolution
        for child in node.children.sorted(by: self.highestPriorityFirst) {
            self.serialize(child, trie: &trie, values: &values)
        }
    }

    private static func highestPriorityFirst(lhs: RouterPathTrieBuilder<Value>.Node, rhs: RouterPathTrieBuilder<Value>.Node) -> Bool {
        lhs.key.priority > rhs.key.priority
    }
}

extension RouterPath.Element {
    fileprivate var priority: Int {
        switch self {
        case .prefixCapture, .suffixCapture:
            // Most specific
            return 1
        case .path, .null:
            // Specific
            return 0
        case .prefixWildcard, .suffixWildcard:
            // Less specific
            return -1
        case .capture:
            // More important than wildcards
            return -2
        case .wildcard:
            // Not specific at all
            return -3
        case .recursiveWildcard:
            // Least specific
            return -4
        }
    }
}
