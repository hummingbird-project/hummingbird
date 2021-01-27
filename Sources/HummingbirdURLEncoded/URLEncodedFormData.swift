
enum URLEncodeFormData: CustomStringConvertible, Equatable {
    case leaf(String?)
    case map(Map = .init())
    case array(Array = .init())

    enum Error: Swift.Error {
        case failedToDecode(String? = nil)
        case notSupported
    }

    init(from string: String) throws {
        self = try Self.decode(string)
    }
    
    var description: String {
        encode("")
    }
    
    func encode(_ prefix: String) -> String {
        switch self {
        case .leaf(let string):
            return string.map { "\(prefix)=\($0)"} ?? ""
        case .array(let array):
            return array.values.map {
                $0.encode("\(prefix)[]")
            }.joined(separator: "&")
        case .map(let map):
            if prefix.count == 0 {
                return map.values.map {
                    $0.value.encode("\($0.key)")
                }.joined(separator: "&")
            } else {
                return map.values.map {
                    $0.value.encode("\(prefix)[\($0.key)]")
                }.joined(separator: "&")
            }
        }
    }
    
    func addValue(keys: ArraySlice<KeyParser.KeyType>, value: String) throws {
        func createNode(from key: KeyParser.KeyType) -> URLEncodeFormData {
            switch key {
            case .array:
                return .array()
            case .map:
                return .map()
            }
        }
        let keyType = keys.first
        let keys = keys.dropFirst()
        switch (self, keyType) {
        case (.map(let map), .map(let key)):
            if keys.count == 0 {
                guard map.values[key] == nil else { throw Error.failedToDecode()}
                map.values[key] = .leaf(value)
            } else {
                if let node = map.values[key] {
                    try node.addValue(keys: keys, value: value)
                } else {
                    let node = createNode(from: keys.first!)
                    map.values[key] = node
                    try node.addValue(keys: keys, value: value)
                }
            }
        case (.array(let array), .array):
            if keys.count == 0 {
                array.values.append(.leaf(value))
            } else {
                // currently don't support arrays and maps inside arrays
                throw Error.notSupported
            }
        default:
            throw Error.failedToDecode()
        }
    }

    static func decode(_ string: String) throws -> URLEncodeFormData {
        var entries: [(String, String)] = []
        let split = string.split(separator: "&")
        let node = Self.map()
        try split.forEach {
            if let equals = $0.firstIndex(of: "=") {
                let before = $0[..<equals].removingPercentEncoding
                let afterEquals = $0.index(after: equals)
                let after = $0[afterEquals...].removingPercentEncoding
                guard let key = before, let value = after else { throw Error.failedToDecode("Failed to percent decode \($0)") }
                entries.append((key: key, value: value))

                guard let keys = KeyParser.parse(key) else { throw Error.failedToDecode("Unexpected key value")}
                try node.addValue(keys: keys[...], value: value)
            }
        }
        return node
    }

    class Map: Equatable {
        var values: [Substring: URLEncodeFormData]
        init(values: [Substring: URLEncodeFormData] = [:]) { self.values = values }
        static func == (lhs: URLEncodeFormData.Map, rhs: URLEncodeFormData.Map) -> Bool {
            lhs.values == rhs.values
        }
    }
    class Array: Equatable {
        var values: [URLEncodeFormData]
        init(values: [URLEncodeFormData] = []) { self.values = values }
        static func == (lhs: URLEncodeFormData.Array, rhs: URLEncodeFormData.Array) -> Bool {
            lhs.values == rhs.values
        }
    }
}

/// Parse URL encoded key
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
                guard let bracketIndex = key[index...].firstIndex(of: "]") else { return nil }
                values.append(.map(key[index..<bracketIndex]))
                index = bracketIndex
                index = key.index(after: index)
            }
        }
        return values
    }
}
