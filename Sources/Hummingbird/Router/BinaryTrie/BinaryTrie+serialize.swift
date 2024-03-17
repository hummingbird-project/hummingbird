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
            trie.writeInteger(TokenKind.path.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the path constant
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(path)
            }
        case .capture(let parameter):
            trie.writeInteger(TokenKind.capture.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .prefixCapture(suffix: let suffix, parameter: let parameter):
            trie.writeInteger(TokenKind.prefixCapture.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the suffix and parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(suffix)
            }
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .suffixCapture(prefix: let prefix, parameter: let parameter):
            trie.writeInteger(TokenKind.suffixCapture.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the prefix and parameter
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(prefix)
            }
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(parameter)
            }
        case .wildcard:
            trie.writeInteger(TokenKind.wildcard.rawValue)
            nextNodeOffsetIndex = reserveUInt32()
        case .prefixWildcard(let suffix):
            trie.writeInteger(TokenKind.prefixWildcard.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the suffix
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(suffix)
            }
        case .suffixWildcard(let prefix):
            trie.writeInteger(TokenKind.suffixWildcard.rawValue)
            nextNodeOffsetIndex = reserveUInt32()

            // Serialize the prefix
            try trie.writeLengthPrefixed(as: Integer.self) { buffer in
                buffer.writeSubstring(prefix)
            }
        case .recursiveWildcard:
            trie.writeInteger(TokenKind.recursiveWildcard.rawValue)
            nextNodeOffsetIndex = reserveUInt32()
        case .null:
            trie.writeInteger(TokenKind.null.rawValue)
            nextNodeOffsetIndex = reserveUInt32()
        }

        try serializeChildren(
            of: node,
            trie: &trie,
            values: &values
        )

        // The last node in a trie is always a null token
        // Since there is no next node to check anymores
        trie.writeInteger(TokenKind.deadEnd.rawValue)

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
