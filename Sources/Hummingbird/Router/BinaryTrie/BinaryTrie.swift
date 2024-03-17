internal final class BinaryTrie<Value: Sendable>: Sendable {
    typealias Integer = UInt8
    let trie: ByteBuffer
    let values: [Value?]

    enum TokenKind: UInt8 {
        case null = 0
        case path, capture, prefixCapture, suffixCapture, wildcard, prefixWildcard, suffixWildcard, recursiveWildcard
        case deadEnd
    }

    init(base: RouterPathTrie<Value>) throws {
        var trie = ByteBufferAllocator().buffer(capacity: 1024)
        var values = [base.root.value]

        try Self.serializeChildren(
            of: base.root,
            trie: &trie,
            values: &values
        )

        self.trie = trie
        self.values = values
    }
}
