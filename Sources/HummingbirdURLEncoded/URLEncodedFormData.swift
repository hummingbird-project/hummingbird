
struct URLEncodeFormData {
    class Map {
        let values: [String: URLEncodeFormData]
        init() { values = [:] }
    }
    class Array {
        let values: [URLEncodeFormData]
        init() { values = [] }
    }
    enum Node {
        case leaf(String)
        case emptyLeaf
        case map(Map)
        case array(Array)
    }
    enum Error: Swift.Error {
        case failedToDecode(String)
    }
    let node: Node

    init(from string: String) throws {
        try self.node = Self.decode(string)
    }

    static func decode(_ string: String) throws -> Node {
        return .leaf(string)
    }

    static func addValue(keys: ArraySlice<KeyParser.KeyType>, value: String) {

    }

    static func unpack(_ string: String) throws -> [(key: String, value: String)] {
        var entries: [(String, String)] = []
        let split = string.split(separator: "&")
        try split.forEach {
            if let equals = $0.firstIndex(of: "=") {
                let before = $0[..<equals].removingPercentEncoding
                let afterEquals = $0.index(after: equals)
                let after = $0[afterEquals...].removingPercentEncoding
                guard let key = before, let value = after else { throw Error.failedToDecode("Failed to percent decode \($0)") }
                entries.append((key: key, value: value))

                let keys = KeyParser.parse(key)
                addValue(keys: keys[...], value: value)
            }
        }
        return entries
    }
}

struct KeyParser {
    enum KeyType: Equatable { case map(Substring), array }

    static func parse(_ key: String) -> [KeyType]? {
        var index = key.startIndex
        var values: [KeyType] = []

        guard let bracketIndex = key.firstIndex(of: "[") else {
            index = key.endIndex
            return [.map(key[...])]
        }
        values.append(.map(key[..<bracketIndex]))
        index = bracketIndex

        while index != key.endIndex {
            guard key[index] == "[" else { return nil }
            index = key.index(after: index)
            // an open bracket is unexpected
            guard index != key.endIndex else { return nil }
            if key[index] == "]" {
                values.append(.array)
                index = key.index(after: index)
            } else {
                // an open bracket is unexpected
                guard let bracketIndex = key.firstIndex(of: "]") else { return nil }
                values.append(.map(key[index..<bracketIndex]))
                index = bracketIndex
                index = key.index(after: index)
            }
        }
        return values
    }
}
