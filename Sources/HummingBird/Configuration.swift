#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


public struct Configuration: Decodable, ExpressibleByDictionaryLiteral {
    
    public init() {
        self.values = Self.getEnvironment()
    }

    public init(values: [String: String]) {
        self.values = [:]
        for (key, value) in values {
            self.values[key.lowercased()] = value
        }
    }
    
    public init(dictionaryLiteral elements: (String, String)...) {
        self.values = [:]
        for element in elements {
            self.values[element.0.lowercased()] = element.1
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: String].self)
    }
    
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
    
    public subscript(_ name: String) -> String? {
        get { return values[name.lowercased()] }
        set { values[name.lowercased()] = newValue }
    }
    
    var port: Int {
        get { return values["port"].map { Int($0) ?? 8000 } ?? 8000 }
        set { values["port"] = newValue.description}
    }
    
    var values: [String: String]
}

