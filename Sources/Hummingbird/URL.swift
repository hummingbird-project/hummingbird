import CURLParser

/// Swift interface to CURLParser
public struct HBURL: CustomStringConvertible, ExpressibleByStringLiteral {
    public struct Scheme: RawRepresentable, Equatable {
        private enum _Scheme: Substring {
            case http
            case https
            case unix
            case http_unix = "http+unix"
            case https_unix = "https+unix"
        }

        private let value: _Scheme

        private init(value: _Scheme) {
            self.value = value
        }

        public init?(rawValue: Substring) {
            guard let value = _Scheme(rawValue: rawValue) else { return nil }
            self.value = value
        }

        public var rawValue: Substring { return self.value.rawValue }

        public static var http: Self { return .init(value: .http) }
        public static var https: Self { return .init(value: .https) }
        public static var unix: Self { return .init(value: .unix) }
        public static var http_unix: Self { return .init(value: .http_unix) }
        public static var https_unix: Self { return .init(value: .https_unix) }
    }

    public let string: String

    public let scheme: Scheme?
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
        return [Substring: Substring].init(queryKeyValues) { lhs, _ in lhs }
    }

    public var description: String { self.string }

    public init(_ string: String) {
        var url = urlparser_url()
        urlparser_parse(string, string.utf8.count, 0, &url)

        self.string = string
        if let scheme = Self.substring(from: url.field_data.0, with: string) {
            self.scheme = Scheme(rawValue: scheme)
        } else {
            self.scheme = nil
        }
        self.host = Self.substring(from: url.field_data.1, with: string)
        if let port = Self.substring(from: url.field_data.2, with: string) {
            self.port = Int(port)
        } else {
            self.port = nil
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
