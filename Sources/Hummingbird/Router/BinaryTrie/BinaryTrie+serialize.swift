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
        _ node: RouterPathTrie<Value>.Node,
        trie: inout ByteBuffer,
        values: inout [Value?]
    ) throws {
        // Index where `value` is located
        trie.writeInteger(UInt16(values.count))
        values.append(node.value)

        var nextNodeOffsetIndex: Int

        // Reserve an UInt32 in space for the next node offset
        func reserveUInt32() -> Int {
            let nextNodeOffsetIndex = trie.writerIndex
            trie.writeInteger(UInt32(0))
            return nextNodeOffsetIndex
        }

        // Serialize the node's component
        switch node.key {
        case .path(let path):
            trie.writeToken(.path)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the path constant
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(path)
            }
        case .capture(let parameter):
            trie.writeToken(.capture)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .prefixCapture(suffix: let suffix, parameter: let parameter):
            trie.writeToken(.prefixCapture)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the suffix and parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(suffix)
            }
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .suffixCapture(prefix: let prefix, parameter: let parameter):
            trie.writeToken(.suffixCapture)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the prefix and parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(prefix)
            }
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .wildcard:
            trie.writeToken(.wildcard)
            nextNodeOffsetIndex = reserveUInt32()
        case .prefixWildcard(let suffix):
            trie.writeToken(.prefixWildcard)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the suffix
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(suffix)
            }
        case .suffixWildcard(let prefix):
            trie.writeToken(.suffixWildcard)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the prefix
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(prefix)
            }
        case .recursiveWildcard:
            trie.writeToken(.recursiveWildcard)
            nextNodeOffsetIndex = reserveUInt32()
        case .null:
            trie.writeToken(.null)
            nextNodeOffsetIndex = reserveUInt32()
        }

        try serializeChildren(
            of: node,
            trie: &trie,
            values: &values
        )

        // The last node in a trie is always a null token
        // Since there is no next node to check anymores
        trie.writeToken(.deadEnd)

        // Write the offset of the next node, always immediately after this node
        // Write a `deadEnd` at the end of this node, and update the current node in case
        // The current node needs to be skipped
        let nextNodeOffset = UInt32(trie.writerIndex + 4)
        trie.writeInteger(nextNodeOffset)
        trie.setInteger(nextNodeOffset, at: nextNodeOffsetIndex)
    }

    static func serializeChildren(
        of node: RouterPathTrie<Value>.Node,
        trie: inout ByteBuffer,
        values: inout [Value?]
    ) throws {
        // Serialize the child nodes in order of priority
        // That's also the order of resolution
        for child in node.children.sorted(by: highestPriorityFirst) {
            try serialize(child, trie: &trie, values: &values)
        }
    }

    private static func highestPriorityFirst(lhs: RouterPathTrie<Value>.Node, rhs: RouterPathTrie<Value>.Node) -> Bool {
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

fileprivate extension ByteBuffer {
    mutating func writeToken(_ token: BinaryTrieTokenKind) {
        writeInteger(token.rawValue)
    }
}
