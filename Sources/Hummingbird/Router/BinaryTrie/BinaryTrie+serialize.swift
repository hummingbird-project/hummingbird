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
        trie: inout Trie,
        values: inout [Value?]
    ) {
        // Index where `value` is located
        let valueIndex = UInt16(values.count)
        values.append(node.value)

        let token: BinaryTrieTokenKind
        let constant: UInt16?
        let parameter: UInt16?

        func setConstant(_ constant: Substring) -> UInt16 {
            if let index = trie.constants.firstIndex(of: constant) {
                return UInt16(index)
            } else {
                let index = UInt16(trie.constants.count)
                trie.constants.append(constant)
                return index
            }
        }

        func setParameter(_ parameter: Substring) -> UInt16 {
            if let index = trie.parameters.firstIndex(of: parameter) {
                return UInt16(index)
            } else {
                let index = UInt16(trie.parameters.count)
                trie.parameters.append(parameter)
                return index
            }
        }

        switch node.key {
        case .path(let path):
            token = .path
            constant = setConstant(path)
            parameter = nil
        case .capture(let parameterName):
            token = .capture
            constant = nil
            parameter = setParameter(parameterName)
        case .prefixCapture(suffix: let suffix, parameter: let parameterName):
            token = .prefixCapture
            constant = setConstant(suffix)
            parameter = setParameter(parameterName)
        case .suffixCapture(prefix: let prefix, parameter: let parameterName):
            token = .suffixCapture
            constant = setConstant(prefix)
            parameter = setParameter(parameterName)
        case .wildcard:
            token = .wildcard
            constant = nil
            parameter = nil
        case .prefixWildcard(let suffix):
            token = .prefixWildcard
            constant = setConstant(suffix)
            parameter = nil
        case .suffixWildcard(let prefix):
            token = .suffixWildcard
            constant = setConstant(prefix)
            parameter = nil
        case .recursiveWildcard:
            token = .recursiveWildcard
            constant = nil
            parameter = nil
        case .null:
            token = .null
            constant = nil
            parameter = nil
        }

        let nodeIndex = trie.nodes.count
        trie.nodes.append(
            BinaryTrieNode(
                valueIndex: valueIndex,
                token: token,
                nextSiblingNodeIndex: .max,
                constant: constant,
                parameter: parameter
            )
        )

        self.serializeChildren(
            of: node,
            trie: &trie,
            values: &values
        )

        trie.nodes[nodeIndex].nextSiblingNodeIndex = UInt16(trie.nodes.count)
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
