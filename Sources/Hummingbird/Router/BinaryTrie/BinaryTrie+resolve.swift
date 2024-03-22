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
        var pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters = Parameters()

        if pathComponents.isEmpty {
            return value(for: 0, parameters: parameters)
        }

        return descendPath(
            in: &trie,
            index: 0,
            parameters: &parameters,
            components: &pathComponents,
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
        _ component: inout Substring, 
        withToken token: TokenKind,
        in trie: inout ByteBuffer,
        parameters: inout Parameters
    ) -> MatchResult {
        switch token {
        case .path:
            // The current node is a constant
            guard
                let length: Integer = trie.readInteger(),
                trie.readAndCompareString(to: &component, length: length)
            else {
                return .mismatch
            }

            return .match
        case .capture:
            // The current node is a parameter
            guard
                let length: Integer = trie.readInteger(),
                let parameter = trie.readString(length: Int(length))
            else {
                return .mismatch
            }

            parameters[Substring(parameter)] = component
            return .match
        case .prefixCapture:
            guard
                let suffixLength: Integer = trie.readInteger(),
                let suffix = trie.readString(length: Int(suffixLength)),
                let parameterLength: Integer = trie.readInteger(),
                let parameter = trie.readString(length: Int(parameterLength)),
                component.hasSuffix(suffix)
            else {
                return .mismatch
            }

            component.removeLast(suffix.count)
            parameters[Substring(parameter)] = component
            return .match
        case .suffixCapture:
            guard
                let prefixLength: Integer = trie.readInteger(),
                let prefix = trie.readString(length: Int(prefixLength)),
                let parameterLength: Integer = trie.readInteger(),
                let parameter = trie.readString(length: Int(parameterLength)),
                component.hasPrefix(prefix)
            else {
                return .mismatch
            }

            component.removeFirst(Int(prefixLength))
            parameters[Substring(parameter)] = component
            return .match
        case .wildcard:
            // Always matches, descend
            return .match
        case .prefixWildcard:
            guard
                let suffixLength: Integer = trie.readInteger(),
                let suffix = trie.readString(length: Int(suffixLength)),
                component.hasSuffix(suffix)
            else {
                return .mismatch
            }

            return .match
        case .suffixWildcard:
            guard
                let prefixLength: Integer = trie.readInteger(),
                let prefix = trie.readString(length: Int(prefixLength)),
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
        parameters: inout Parameters,
        components: inout [Substring],
        isInRecursiveWildcard: Bool
    ) -> (value: Value, parameters: Parameters)? {
        // If there are no more components in the path, return the value found
        if components.isEmpty {
            return value(for: index, parameters: parameters)
        }

        // Take the next component from the path
        var component = components.removeFirst()
        
        // Check the current node type through TokenKind
        // And read the location of the _next_ node from the trie buffer
        while 
            let index = trie.readInteger(as: UInt16.self),
            let _token: Integer = trie.readInteger(),
            let token = TokenKind(rawValue: _token),
            let nextSiblingNodeIndex: UInt32 = trie.readInteger()
        {
            repeat {
                // Record the current readerIndex
                // ``matchComponent`` moves the reader index forward, so we'll need to reset it
                // If we're in a recursiveWildcard and this component does not match
                let readerIndex = trie.readerIndex
                let result = matchComponent(&component, withToken: token, in: &trie, parameters: &parameters)

                switch result {
                case .match:
                    return descendPath(
                        in: &trie,
                        index: index,
                        parameters: &parameters,
                        components: &components,
                        isInRecursiveWildcard: false
                    )
                case .mismatch where isInRecursiveWildcard:
                    if components.isEmpty {
                        return nil
                    }

                    component = components.removeFirst()
                    // Move back he readerIndex, so that we can retry this step again with
                    // the next component
                    trie.moveReaderIndex(to: readerIndex)
                case .mismatch:
                    // Move to the next sibling-node, not descending a level
                    trie.moveReaderIndex(to: Int(nextSiblingNodeIndex))
                    continue
                case .recursivelyDiscarded:
                    return descendPath(
                        in: &trie,
                        index: index,
                        parameters: &parameters,
                        components: &components,
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

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Musl)
import Musl
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
#error("unsupported os")
#endif

fileprivate extension ByteBuffer {
    mutating func readAndCompareString<Length: FixedWidthInteger>(to string: inout Substring, length: Length) -> Bool {
        let length = Int(length)
        return string.withUTF8 { utf8 in
            if utf8.count != length {
                return false
            }

            if length == 0 {
                // Needed, because `memcmp` wants a non-null pointer on Linux
                // and a zero-length buffer has no baseAddress
                return true
            }

            return withUnsafeReadableBytes { buffer in
                if memcmp(utf8.baseAddress!, buffer.baseAddress!, length) == 0 {
                    moveReaderIndex(forwardBy: length)
                    return true
                } else {
                    return false
                }
            }
        }
    }
}
