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
    @usableFromInline
    static func serialize(
        _ node: RouterPathTrieBuilder<Value>.Node,
        trie: inout Trie,
        values: inout [Value?]
    ) {
        // Index where `value` is located
        let valueIndex = values.count
        values.append(node.value)

        let token: TrieToken

        func setConstant(_ constant: Substring) -> UInt16 {
            if let index = trie.constants.firstIndex(of: constant) {
                return UInt16(index)
            } else {
                let index = trie.constants.count
                trie.constants.append(constant)
                return UInt16(index)
            }
        }

        func setParameter(_ parameter: Substring) -> UInt16 {
            if let index = trie.parameters.firstIndex(of: parameter) {
                return UInt16(index)
            } else {
                let index = trie.parameters.count
                trie.parameters.append(parameter)
                return UInt16(index)
            }
        }

        switch node.key {
        case .path(let path):
            token = .path(constantIndex: setConstant(path))
        case .capture(let parameterName):
            token = .capture(parameterIndex: setParameter(parameterName))
        case .prefixCapture(suffix: let suffix, parameter: let parameterName):
            token = .prefixCapture(
                parameterIndex: setParameter(parameterName),
                suffixIndex: setConstant(suffix)
            )
        case .suffixCapture(prefix: let prefix, parameter: let parameterName):
            token = .suffixCapture(
                prefixIndex: setConstant(prefix),
                parameterIndex: setParameter(parameterName)
            )
        case .wildcard:
            token = .wildcard
        case .prefixWildcard(let suffix):
            token = .prefixWildcard(suffixIndex: setConstant(suffix))
        case .suffixWildcard(let prefix):
            token = .suffixWildcard(prefixIndex: setConstant(prefix))
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

    @usableFromInline
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
    }

    @usableFromInline
    internal static func highestPriorityFirst(lhs: RouterPathTrieBuilder<Value>.Node, rhs: RouterPathTrieBuilder<Value>.Node) -> Bool {
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
