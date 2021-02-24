#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import CURLParser

/// Swift interface to CURLParser
public struct HBURL: CustomStringConvertible, ExpressibleByStringLiteral, Equatable {
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

    public var host: String? { return self._host.map { String($0) }}
    public var port: Int? { return self._port.map { Int($0) } ?? nil }
    public var path: String { String(self._path) }
    public var query: String? { return self._query.map { String($0) }}
    public var fragment: String? { return self._fragment.map { String($0) }}
    public var queryParameters: HBParameters { return .init(fromQuery: self._query) }

    private let _host: Substring?
    private let _port: Substring?
    private let _path: Substring
    private let _query: Substring?
    private let _fragment: Substring?

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
        self._host = Self.substring(from: url.field_data.1, with: string)
        self._port = Self.substring(from: url.field_data.2, with: string)
        self._path = Self.substring(from: url.field_data.3, with: string)?.removingPercentEncoding ?? "/"
        self._query = Self.substring(from: url.field_data.4, with: string)
        self._fragment = Self.substring(from: url.field_data.5, with: string)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    private static func substring(from data: urlparser_field_data, with string: String) -> Substring? {
        guard data.len > 0 else { return nil }
        // this code relies on the fact we are being supplied ASCII 127 characters. Fortunately in this
        // case that is correct
        let start = string.index(string.startIndex, offsetBy: numericCast(data.off))
        let end = string.index(start, offsetBy: numericCast(data.len))

        return string[start..<end]
    }
}

private extension Substring {
    /// Local copy of removingPercentEncoding so I don't need to include Foundation
    var removingPercentEncoding: Substring {
        struct RemovePercentEncodingError: Error {}
        // if no % characters in string, don't waste time allocating a new string
        guard self.contains("%") else { return self }

        do {
            let size = self.utf8.count + 1
            if #available(macOS 11, *) {
                let result = try String(unsafeUninitializedCapacity: size) { buffer -> Int in
                    try self.withCString { cstr -> Int in
                        let len = urlparser_remove_percent_encoding(cstr, numericCast(self.utf8.count), buffer.baseAddress, size)
                        guard len > 0 else { throw RemovePercentEncodingError() }
                        return numericCast(len)
                    }
                }
                return result[...]
            } else {
                // allocate buffer size of original string and run remove percent encoding
                let mem = UnsafeMutablePointer<UInt8>.allocate(capacity: count + 1)
                try self.withCString { cstr in
                    let len = urlparser_remove_percent_encoding(cstr, numericCast(self.utf8.count), mem, 1024)
                    guard len > 0 else { throw RemovePercentEncodingError() }
                }
                let result = String(cString: mem)
                mem.deallocate()
                return result[...]
            }
        } catch {
            return self
        }
    }
}

extension HBParameters {
    init(fromQuery query: Substring?) {
        guard let query = query else {
            self.parameters = [:]
            return
        }
        let queries = query.split(separator: "&")
        let queryKeyValues = queries.map { value -> (key: Substring, value: Substring) in
            if let equals = value.firstIndex(of: "=") {
                return (key: value[..<equals].removingPercentEncoding, value: value[value.index(after: equals)...].removingPercentEncoding)
            }
            return (key: value, value: "")
        }
        self.parameters = [Substring: Substring].init(queryKeyValues) { lhs, _ in lhs }
    }
}
