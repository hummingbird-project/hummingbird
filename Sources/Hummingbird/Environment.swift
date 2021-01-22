#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

/// Environment variables
public struct HBEnvironment: Decodable, ExpressibleByDictionaryLiteral {
    /// initialize from environment variables
    public init() {
        self.values = Self.getEnvironment()
    }

    /// initialize from dictionary
    public init(values: [String: String]) {
        self.values = Self.getEnvironment()
        for (key, value) in values {
            self.values[key.lowercased()] = value
        }
    }

    /// initialize from dictionary literal
    public init(dictionaryLiteral elements: (String, String)...) {
        self.values = Self.getEnvironment()
        for element in elements {
            self.values[element.0.lowercased()] = element.1
        }
    }

    /// Initialize from Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: String].self)
    }

    public func get(_ s: String) -> String? {
        return values[s.lowercased()]
    }

    public func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        return values[s.lowercased()].map { T(String($0)) } ?? nil
    }

    public mutating func set(_ s: String, value: String?) {
        values[s.lowercased()] = value
    }

    /// Get environment variables
    static func getEnvironment() -> [String: String] {
        var values: [String: String] = [:]
        let equalSign = Character("=")
        let envp = environ
        var idx = 0

        while let entry = envp.advanced(by: idx).pointee {
            let entry = String(cString: entry)
            if let i = entry.firstIndex(of: equalSign) {
                let key = String(entry.prefix(upTo: i))
                let value = String(entry.suffix(from: i).dropFirst())
                values[key.lowercased()] = value
            }
            idx += 1
        }
        return values
    }

    var values: [String: String]
}
