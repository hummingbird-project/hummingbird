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
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters = Parameters()
        guard var node: BinaryTrieNode = trie.readBinaryTrieNode() else { return nil }
        for component in pathComponents {
            if node.token != .recursiveWildcard {
                node = self.matchComponent(component, in: &trie, parameters: &parameters)
                if node.token == .recursiveWildcard {
                    parameters.setCatchAll(path[component.startIndex...])
                }
            }
            if node.token == .deadEnd {
                return nil
            }
        }
        return self.value(for: node.index, parameters: parameters)
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
        in trie: inout ByteBuffer,
        parameters: inout Parameters
    ) -> BinaryTrieNode {
        while let node = trie.readBinaryTrieNode() {
            let result = self.matchComponent(component, withToken: node.token, in: &trie, parameters: &parameters)
            switch result {
            case .match, .deadEnd:
                return node
            default:
                trie.moveReaderIndex(to: Int(node.nextSiblingNodeIndex))
            }
        }
        // should never get here
        return .init(index: 0, token: .deadEnd, nextSiblingNodeIndex: UInt32(trie.writerIndex))
    }

    private enum MatchResult {
        case match, mismatch, ignore, deadEnd
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
            return .match
        case .null:
            return .ignore
        case .deadEnd:
            return .deadEnd
        }
    }
}
