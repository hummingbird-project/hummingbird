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
        var trie = trie
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)[...]
        let parameters = Parameters()

        if pathComponents.isEmpty {
            return self.value(for: 0, parameters: parameters)
        }

        return self.descendPath(
            in: &trie,
            index: 0,
            parameters: parameters,
            components: pathComponents,
            isInRecursiveWildcard: false
        )
    }

    /// If `index != nil`, resolves the `index` to a `Value`
    /// This is used as a helper in `descendPath(in:parameters:components:)`
    private func value(for index: UInt16?, parameters: Parameters) -> (value: Value, parameters: Parameters)? {
        if let index, let value = self.values[Int(index)] {
            return (value: value, parameters: parameters)
        }

        return nil
    }

    private enum MatchResult {
        case match, mismatch, recursivelyDiscarded, ignore, deadEnd
    }

    private func matchComponent(
        _ component: Substring,
        withToken token: BinaryTrieTokenKind,
        in trie: inout ByteBuffer,
        parameters: inout Parameters
    ) -> MatchResult {
        switch token {
        case .path:
            // The current node is a constant
            guard
                trie.readAndCompareString(
                    to: component,
                    length: Integer.self
                )
            else {
                return .mismatch
            }

            return .match
        case .capture:
            // The current node is a parameter
            guard
                let parameter = trie.readLengthPrefixedString(as: Integer.self)
            else {
                return .mismatch
            }

            parameters[Substring(parameter)] = component
            return .match
        case .prefixCapture:
            guard
                let suffix = trie.readLengthPrefixedString(as: Integer.self),
                let parameter = trie.readLengthPrefixedString(as: Integer.self),
                component.hasSuffix(suffix)
            else {
                return .mismatch
            }

            parameters[Substring(parameter)] = component.dropLast(suffix.count)
            return .match
        case .suffixCapture:
            guard
                let prefix = trie.readLengthPrefixedString(as: Integer.self),
                let parameter = trie.readLengthPrefixedString(as: Integer.self),
                component.hasPrefix(prefix)
            else {
                return .mismatch
            }

            parameters[Substring(parameter)] = component.dropFirst(prefix.count)
            return .match
        case .wildcard:
            // Always matches, descend
            return .match
        case .prefixWildcard:
            guard
                let suffix = trie.readLengthPrefixedString(as: Integer.self),
                component.hasSuffix(suffix)
            else {
                return .mismatch
            }

            return .match
        case .suffixWildcard:
            guard
                let prefix = trie.readLengthPrefixedString(as: Integer.self),
                component.hasPrefix(prefix)
            else {
                return .mismatch
            }

            return .match
        case .recursiveWildcard:
            return .recursivelyDiscarded
        case .null:
            return .ignore
        case .deadEnd:
            return .deadEnd
        }
    }

    /// A function that takes a path component and descends the trie to find the value
    private func descendPath(
        in trie: inout ByteBuffer,
        index: UInt16,
        parameters: Parameters,
        components: ArraySlice<Substring>,
        isInRecursiveWildcard: Bool
    ) -> (value: Value, parameters: Parameters)? {
        var parameters = parameters
        // If there are no more components in the path, return the value found
        if components.isEmpty {
            return self.value(for: index, parameters: parameters)
        }

        // Take the next component from the path. If there are no more components in the
        // path, return the value found
        guard var component = components.first else {
            return self.value(for: index, parameters: parameters)
        }
        var components = components.dropFirst()

        // Check the current node type through TokenKind
        // And read the location of the _next_ node from the trie buffer
        while let node = trie.readBinaryTrieNode() {
            repeat {
                // Record the current readerIndex
                // ``matchComponent`` moves the reader index forward, so we'll need to reset it
                // If we're in a recursiveWildcard and this component does not match
                let readerIndex = trie.readerIndex
                let result = self.matchComponent(component, withToken: node.token, in: &trie, parameters: &parameters)

                switch result {
                case .match:
                    return self.descendPath(
                        in: &trie,
                        index: node.index,
                        parameters: parameters,
                        components: components,
                        isInRecursiveWildcard: false
                    )
                case .mismatch where isInRecursiveWildcard:
                    guard let c = components.first else {
                        return nil
                    }
                    component = c
                    components = components.dropFirst()

                    // Move back he readerIndex, so that we can retry this step again with
                    // the next component
                    trie.moveReaderIndex(to: readerIndex)
                case .mismatch:
                    // Move to the next sibling-node, not descending a level
                    trie.moveReaderIndex(to: Int(node.nextSiblingNodeIndex))
                    continue
                case .recursivelyDiscarded:
                    return self.descendPath(
                        in: &trie,
                        index: node.index,
                        parameters: parameters,
                        components: components,
                        isInRecursiveWildcard: true
                    )
                case .ignore:
                    continue
                case .deadEnd:
                    return nil
                }
            } while isInRecursiveWildcard
        }

        return nil
    }
}
