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
    /// Resolve a path to a `Value` if available
    @inlinable
    @_spi(Internal) public func resolve(_ path: String) -> (value: Value, parameters: Parameters)? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var pathComponentsIterator = pathComponents.makeIterator()
        var parameters = Parameters()

        var node = trie.nodes[0]
        var nodeIndex = 1

        while let component = pathComponentsIterator.next() {
            node = self.matchComponent(component, atNodeIndex: &nodeIndex, parameters: &parameters)
            if node.token == .recursiveWildcard {
                // we have found a recursive wildcard. Go through all the path components until we match one of them
                // or reach the end of the path component array
                var range = component.startIndex..<component.endIndex
                while let component = pathComponentsIterator.next() {
                    var nodeIndex = nodeIndex
                    let recursiveNode = self.matchComponent(component, atNodeIndex: &nodeIndex, parameters: &parameters)
                    if recursiveNode.token != .deadEnd {
                        node = recursiveNode
                        break
                    }
                    // extend range of catch all text
                    range = range.lowerBound..<component.endIndex
                }
                parameters.setCatchAll(path[range])
            }
            if node.token == .deadEnd {
                return nil
            }
        }

        if let value = self.values[node.valueIndex] {
            return (value: value, parameters: parameters)
        } else {
            return nil
        }
    }

    /// Match sibling node for path component
    @inlinable
    internal func matchComponent(
        _ component: Substring,
        atNodeIndex nodeIndex: inout Int,
        parameters: inout Parameters
    ) -> TrieNode {
        while nodeIndex < trie.nodes.count {
            let node = trie.nodes[nodeIndex]
            let result = self.matchComponent(
                component,
                node: node,
                parameters: &parameters
            )
            switch result {
            case .match, .deadEnd:
                nodeIndex += 1
                return node
            default:
                nodeIndex = Int(node.nextSiblingNodeIndex)
            }
        }

        // should never get here
        return TrieNode(valueIndex: 0, token: .deadEnd, nextSiblingNodeIndex: .max)
    }

    @usableFromInline
    enum MatchResult {
        case match, mismatch, ignore, deadEnd
    }

    @inlinable
    func matchComponent(
        _ component: Substring,
        node: TrieNode,
        parameters: inout Parameters
    ) -> MatchResult {
        switch node.token {
        case .path(let constant):
            // The current node is a constant
            if trie.stringValues[Int(constant)] == component {
                return .match
            }

            return .mismatch
        case .capture(let parameter):
            parameters[trie.stringValues[Int(parameter)]] = component
            return .match
        case .prefixCapture(let parameter, let suffix):
            let suffix = trie.stringValues[Int(suffix)]

            if component.hasSuffix(suffix) {
                parameters[trie.stringValues[Int(parameter)]] = component.dropLast(suffix.count)
                return .match
            }

            return .mismatch
        case .suffixCapture(let prefix, let parameter):
            let prefix = trie.stringValues[Int(prefix)]
            if component.hasPrefix(prefix) {
                parameters[trie.stringValues[Int(parameter)]] = component.dropFirst(prefix.count)
                return .match
            }

            return .mismatch
        case .wildcard:
            // Always matches, descend
            return .match
        case .prefixWildcard(let suffix):
            if component.hasSuffix(trie.stringValues[Int(suffix)]) {
                return .match
            }

            return .mismatch
        case .suffixWildcard(let prefix):
            if component.hasPrefix(trie.stringValues[Int(prefix)]) {
                return .match
            }

            return .mismatch
        case .recursiveWildcard:
            return .match
        case .null:
            return .ignore
        case .deadEnd:
            return .deadEnd
        }
    }
}
