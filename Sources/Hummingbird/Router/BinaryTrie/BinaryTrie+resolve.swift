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
    /// Resolve a path to a `Value` if available
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

        return self.value(for: node.valueIndex, parameters: parameters)
    }

    /// If `index != nil`, resolves the `index` to a `Value`
    /// This is used as a helper in `descendPath(in:parameters:components:)`
    private func value(for index: UInt16?, parameters: Parameters) -> (value: Value, parameters: Parameters)? {
        if let index, let value = self.values[Int(index)] {
            return (value: value, parameters: parameters)
        }

        return nil
    }

    /// Match sibling node for path component
    private func matchComponent(
        _ component: Substring,
        atNodeIndex nodeIndex: inout Int,
        parameters: inout Parameters
    ) -> BinaryTrieNode {
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
        return BinaryTrieNode(valueIndex: 0, token: .deadEnd, nextSiblingNodeIndex: .max)
    }

    private enum MatchResult {
        case match, mismatch, ignore, deadEnd
    }

    private func matchComponent(
        _ component: Substring,
        node: BinaryTrieNode,
        parameters: inout Parameters
    ) -> MatchResult {
        switch node.token {
        case .path:
            // The current node is a constant
            guard
                let constant = node.constant,
                trie.constants[Int(constant)] == component
            else {
                return .mismatch
            }

            return .match
        case .capture:
            // The current node is a parameter
            guard let parameter = node.parameter else {
                return .mismatch
            }

            parameters[trie.parameters[Int(parameter)]] = component
            return .match
        case .prefixCapture:
            guard
                let constant = node.constant,
                let parameter = node.parameter
            else {
                return .mismatch
            }

            let suffix = trie.constants[Int(constant)]

            guard component.hasSuffix(suffix) else {
                return .mismatch
            }

            parameters[trie.parameters[Int(parameter)]] = component.dropLast(suffix.count)
            return .match
        case .suffixCapture:
            guard
                let constant = node.constant,
                let parameter = node.parameter,
                component.hasPrefix(trie.constants[Int(constant)])
            else {
                return .mismatch
            }

            let prefix = trie.constants[Int(constant)]

            guard component.hasPrefix(prefix) else {
                return .mismatch
            }

            parameters[trie.parameters[Int(parameter)]] = component.dropFirst(prefix.count)
            return .match
        case .wildcard:
            // Always matches, descend
            return .match
        case .prefixWildcard:
            guard
                let constant = node.constant,
                component.hasSuffix(trie.constants[Int(constant)])
            else {
                return .mismatch
            }

            return .match
        case .suffixWildcard:
            guard
                let constant = node.constant,
                component.hasPrefix(trie.constants[Int(constant)])
            else {
                return .mismatch
            }

            return .match
        case .recursiveWildcard:
            return .match
        case .null:
            return .ignore
        case .deadEnd:
            return .deadEnd
        }
    }
}
