import CURLParser

public struct URI: CustomStringConvertible, ExpressibleByStringLiteral {
    public let string: String

    public let scheme: Substring?
    public let host: Substring?
    public let port: Int?
    public let path: Substring
    public let query: Substring?
    public let fragment: Substring?
    public var queryParameters: [Substring: Substring] {
        guard let query = query else { return [:] }
        let queries = query.split(separator: "&")
        let queryKeyValues = queries.map { value -> (key: Substring, value: Substring) in
            if let equals = value.firstIndex(of: "=") {
                return (key: value[..<equals], value: value[value.index(after: equals)...])
            }
            return (key: value, value: "")
        }
        return [Substring: Substring].init(queryKeyValues) { lhs,_ in lhs }
    }

    public var description: String { string }

    public init(_ string: String) {
        var url = urlparser_url()
        urlparser_parse(string, string.utf8.count, 0, &url)

        self.string = string
        self.scheme = Self.substring(from: url.field_data.0, with: string)
        self.host = Self.substring(from: url.field_data.1, with: string)
        if let port = Self.substring(from: url.field_data.2, with: string) {
            self.port = Int(port)
        } else {
            port = nil
        }
        self.path = Self.substring(from: url.field_data.3, with: string) ?? "/"
        self.query = Self.substring(from: url.field_data.4, with: string)
        self.fragment = Self.substring(from: url.field_data.5, with: string)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
    
    private static func substring(from data: urlparser_field_data, with string: String) -> Substring? {
        guard data.len > 0 else { return nil }
        let start = string.index(string.startIndex, offsetBy: numericCast(data.off))
        let end = string.index(start, offsetBy: numericCast(data.len))
        return string[start..<end]
    }
}
