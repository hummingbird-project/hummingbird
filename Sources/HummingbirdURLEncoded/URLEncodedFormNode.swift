
enum URLEncodedFormNode: CustomStringConvertible, Equatable {
    case leaf(NodeValue?)
    case map(Map)
    case array(Array)

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
    
    static func decode(_ string: String) throws -> URLEncodedFormNode {
        let split = string.split(separator: "&")
        let node = Self.map(.init())
        try split.forEach {
            if let equals = $0.firstIndex(of: "=") {
                let before = $0[..<equals].removingPercentEncoding
                let afterEquals = $0.index(after: equals)
                let after = $0[afterEquals...].replacingOccurrences(of: "+", with: " ")
                guard let key = before else { throw Error.failedToDecode("Failed to percent decode \($0)") }

                guard let keys = KeyParser.parse(key) else { throw Error.failedToDecode("Unexpected key value")}
                guard let value = NodeValue(percentEncoded: after) else { throw Error.failedToDecode("Failed to percent decode \(after)")}

                try node.addValue(keys: keys[...], value: value)
            }
        }
        return node
    }

    func addValue(keys: ArraySlice<KeyParser.KeyType>, value: NodeValue) throws {
        func createNode(from key: KeyParser.KeyType) -> URLEncodedFormNode {
            switch key {
            case .array:
                return .array(.init())
            case .map:
                return .map(.init())
            }
        }
        let keyType = keys.first
        let keys = keys.dropFirst()
        switch (self, keyType) {
        case (.map(let map), .map(let key)):
            let key = String(key)
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

    private func encode(_ prefix: String) -> String {
        switch self {
        case .leaf(let string):
            return string.map { "\(prefix)=\($0.percentEncoded)"} ?? ""
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
    
    class NodeValue: Equatable {
        /// string value of node (with percent encoding removed)
        var value: String

        init(_ value: LosslessStringConvertible) {
            self.value = String(describing: value)
        }
        init?(percentEncoded value: String) {
            guard let value = value.removingPercentEncoding else { return nil }
            self.value = value
        }

        var percentEncoded: String {
            return value.addingPercentEncoding(withAllowedCharacters: URLEncodedForm.unreservedCharacters) ?? value
        }

        static func == (lhs: URLEncodedFormNode.NodeValue, rhs: URLEncodedFormNode.NodeValue) -> Bool {
            lhs.value == rhs.value
        }
    }
    class Map: Equatable {
        var values: [String: URLEncodedFormNode]
        init(values: [String: URLEncodedFormNode] = [:]) {
            self.values = values
        }
        
        func addChild(key: String, value: URLEncodedFormNode) {
            self.values[key] = value
        }
        
        static func == (lhs: URLEncodedFormNode.Map, rhs: URLEncodedFormNode.Map) -> Bool {
            lhs.values == rhs.values
        }
    }
    class Array: Equatable {
        var values: [URLEncodedFormNode]
        init(values: [URLEncodedFormNode] = []) {
            self.values = values
        }
        
        func addChild(value: URLEncodedFormNode) {
            self.values.append(value)
        }
        
        static func == (lhs: URLEncodedFormNode.Array, rhs: URLEncodedFormNode.Array) -> Bool {
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
