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

extension RouterTrie {
    static func serialize(
        _ node: RouterPathTrieBuilder<Value>.Node,
        trie: inout Trie,
        values: inout [Value?]
    ) {
        // Index where `value` is located
        let valueIndex = values.count
        values.append(node.value)

        let token: TrieToken

        func setStringValue(_ constant: Substring) -> UInt32 {
            if let index = trie.stringValues.firstIndex(of: constant) {
                return UInt32(index)
            } else {
                let index = trie.stringValues.count
                trie.stringValues.append(constant)
                return UInt32(index)
            }
        }

        switch node.key {
        case .path(let path):
            token = .path(constantIndex: setStringValue(path))
        case .capture(let parameterName):
            token = .capture(parameterIndex: setStringValue(parameterName))
        case .prefixCapture(suffix: let suffix, parameter: let parameterName):
            token = .prefixCapture(
                parameterIndex: setStringValue(parameterName),
                suffixIndex: setStringValue(suffix)
            )
        case .suffixCapture(prefix: let prefix, parameter: let parameterName):
            token = .suffixCapture(
                prefixIndex: setStringValue(prefix),
                parameterIndex: setStringValue(parameterName)
            )
        case .wildcard:
            token = .wildcard
        case .prefixWildcard(let suffix):
            token = .prefixWildcard(suffixIndex: setStringValue(suffix))
        case .suffixWildcard(let prefix):
            token = .suffixWildcard(prefixIndex: setStringValue(prefix))
        case .recursiveWildcard:
            token = .recursiveWildcard
        case .null:
            token = .null
        }

        let nodeIndex = trie.nodes.count
        trie.nodes.append(
            TrieNode(
                valueIndex: valueIndex,
                token: token,
                nextSiblingNodeIndex: .max
            )
        )

        self.serializeChildren(
            of: node,
            trie: &trie,
            values: &values
        )

        trie.nodes[nodeIndex].nextSiblingNodeIndex = trie.nodes.count
    }

    static func serializeChildren(
        of node: RouterPathTrieBuilder<Value>.Node,
        trie: inout Trie,
        values: inout [Value?]
    ) {
        // Serialize the child nodes in order of priority
        // That's also the order of resolution
        for child in node.children.sorted(by: self.highestPriorityFirst) {
            self.serialize(child, trie: &trie, values: &values)
        }

        trie.nodes.append(
            TrieNode(
                valueIndex: -1,
                token: .deadEnd,
                nextSiblingNodeIndex: .max
            )
        )
    }

    internal static func highestPriorityFirst(lhs: RouterPathTrieBuilder<Value>.Node, rhs: RouterPathTrieBuilder<Value>.Node) -> Bool {
        lhs.key.priority > rhs.key.priority
    }
}

extension RouterPath.Element {
    @usableFromInline
    var priority: Int {
        switch self {
        case .path, .null:
            // Most specific
            return 0
        case .prefixCapture, .suffixCapture:
            // specific
            return -1
        case .prefixWildcard, .suffixWildcard:
            // Less specific
            return -2
        case .capture:
            // More important than wildcards
            return -3
        case .wildcard:
            // Not specific at all
            return -4
        case .recursiveWildcard:
            // Least specific
            return -5
        }
    }
}
