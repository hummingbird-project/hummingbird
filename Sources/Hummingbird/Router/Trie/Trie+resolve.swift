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
    public func resolve(_ path: String) -> (value: Value, parameters: Parameters)? {
        var context = ResolveContext(path: path, trie: trie, values: values)
        return context.resolve()
    }

    @usableFromInline
    struct ResolveContext {
        @usableFromInline let path: String
        @usableFromInline let pathComponents: [Substring]
        @usableFromInline let trie: Trie
        @usableFromInline let values: [Value?]
        @usableFromInline var parameters = Parameters()

        @usableFromInline init(path: String, trie: Trie, values: [Value?]) {
            self.path = path
            self.trie = trie
            self.pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
            self.values = values
        }

        @usableFromInline func nextPathComponent(advancingIndex index: inout Int) -> Substring? {
            if index >= self.pathComponents.count {
                return nil
            }

            let component = self.pathComponents[index]
            index += 1
            return component
        }

        @inlinable
        mutating func resolve() -> (value: Value, parameters: Parameters)? {
            guard let component = pathComponents.first else {
                guard let value = values[trie.nodes[0].valueIndex] else {
                    return nil
                }

                return (value: value, parameters: self.parameters)
            }

            var nodeIndex = 1
            guard
                let node = descend(
                    component: component,
                    nextPathComponentIndex: 1,
                    nodeIndex: &nodeIndex
                )
            else {
                return nil
            }

            if let value = values[node.valueIndex] {
                return (value: value, parameters: self.parameters)
            } else {
                return nil
            }
        }

        @inlinable
        mutating func descend(
            component: Substring,
            nextPathComponentIndex: Int,
            nodeIndex: inout Int
        ) -> TrieNode? {
            var node = self.matchComponent(component, atNodeIndex: &nodeIndex)
            var nextPathComponentIndex = nextPathComponentIndex

            if node.token == .recursiveWildcard {
                // we have found a recursive wildcard. Go through all the path components until we match one of them
                // or reach the end of the path component array
                var range = component.startIndex..<component.endIndex

                while let component = nextPathComponent(advancingIndex: &nextPathComponentIndex) {
                    var _nodeIndex = nodeIndex
                    let recursiveNode = self.matchComponent(component, atNodeIndex: &_nodeIndex)
                    if recursiveNode.token != .deadEnd {
                        node = recursiveNode
                        nodeIndex = _nodeIndex
                        break
                    }
                    // extend range of catch all text
                    range = range.lowerBound..<component.endIndex
                }
                self.parameters.setCatchAll(self.path[range])
            }

            if node.token == .deadEnd {
                return nil
            }

            if let nextComponent = nextPathComponent(advancingIndex: &nextPathComponentIndex) {
                // There's another component to the route
                var nextIndex = nodeIndex

                // If a dead end is found, we're done
                while self.trie.nodes[nextIndex].token != .deadEnd {
                    if let node = descend(
                        component: nextComponent,
                        nextPathComponentIndex: nextPathComponentIndex,
                        nodeIndex: &nodeIndex
                    ) {
                        return node
                    }
                    nextIndex = self.trie.nodes[nextIndex].nextSiblingNodeIndex
                    nodeIndex = nextIndex
                }

                return nil
            } else {
                return node
            }
        }

        /// Match sibling node for path component
        @inlinable
        mutating func matchComponent(_ component: Substring, atNodeIndex nodeIndex: inout Int) -> TrieNode {
            while nodeIndex < self.trie.nodes.count {
                let node = self.trie.nodes[nodeIndex]
                let result = self.matchComponent(component, node: node)
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
        mutating func matchComponent(_ component: Substring, node: TrieNode) -> MatchResult {
            switch node.token {
            case .path(let constant):
                // The current node is a constant
                if self.trie.stringValues[Int(constant)] == component {
                    return .match
                }

                return .mismatch
            case .capture(let parameter):
                self.parameters[self.trie.stringValues[Int(parameter)]] = component
                return .match
            case .prefixCapture(let parameter, let suffix):
                let suffix = self.trie.stringValues[Int(suffix)]

                if component.hasSuffix(suffix) {
                    self.parameters[self.trie.stringValues[Int(parameter)]] = component.dropLast(suffix.count)
                    return .match
                }

                return .mismatch
            case .suffixCapture(let prefix, let parameter):
                let prefix = self.trie.stringValues[Int(prefix)]
                if component.hasPrefix(prefix) {
                    self.parameters[self.trie.stringValues[Int(parameter)]] = component.dropFirst(prefix.count)
                    return .match
                }

                return .mismatch
            case .wildcard:
                // Always matches, descend
                return .match
            case .prefixWildcard(let suffix):
                if component.hasSuffix(self.trie.stringValues[Int(suffix)]) {
                    return .match
                }

                return .mismatch
            case .suffixWildcard(let prefix):
                if component.hasPrefix(self.trie.stringValues[Int(prefix)]) {
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
}
