import CURLParser

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

public struct HBURL: CustomStringConvertible, ExpressibleByStringLiteral {
    public struct Scheme: RawRepresentable, Equatable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static var http: Self { return .init(rawValue: "http") }
        public static var https: Self { return .init(rawValue: "https") }
        public static var unix: Self { return .init(rawValue: "unix") }
        public static var http_unix: Self { return .init(rawValue: "http_unix") }
        public static var https_unix: Self { return .init(rawValue: "https_unix") }
    }

    public let string: String

    /// URL scheme
    public var scheme: Scheme? { return self._scheme.map { .init(rawValue: $0.string) } }
    /// URL host
    public var host: String? { return self._host.map { $0.string }}
    /// URL port
    public var port: Int? { return self._port.map { Int($0.string) } ?? nil }
    /// URL path
    public var path: String { return self._path.map { $0.string } ?? "/" }
    /// URL query
    public var query: String? { return self._query.map { String($0.string) }}
    /// URL query parameter map
    public var queryParameters: HBParameters { return .init(fromQuery: self._query) }

    private let _scheme: Parser?
    private let _host: Parser?
    private let _port: Parser?
    private let _path: Parser?
    private let _query: Parser?

    public var description: String { self.string }

    public init(_ string: String) {
        enum ParsingState {
            case readingScheme
            case readingHost
            case readingPort
            case readingPath
            case readingQuery
            case finished
        }
        var scheme: Parser? = nil
        var host: Parser? = nil
        var port: Parser? = nil
        var path: Parser? = nil
        var query: Parser? = nil
        var state: ParsingState = .readingScheme

        var parser = Parser(string)
        while state != .finished {
            if parser.reachedEnd() { break }
            switch state {
            case .readingScheme:
                // search for "://" to find scheme and host
                scheme = try? parser.read(untilString: "://", skipToEnd: true)
                if scheme != nil {
                    state = .readingHost
                } else {
                    state = .readingPath
                }

            case .readingHost:
                let h = try! parser.read(until: Self.hostEndSet, throwOnOverflow: false)
                if h.count != 0 {
                    host = h
                }
                if parser.current() == ":" {
                    state = .readingPort
                } else if parser.current() == "?" {
                    state = .readingQuery
                } else {
                    state = .readingPath
                }

            case .readingPort:
                parser.unsafeAdvance()
                port = try! parser.read(until: Self.portEndSet, throwOnOverflow: false)
                state = .readingPath

            case .readingPath:
                path = try! parser.read(until: "?", throwOnOverflow: false)
                state = .readingQuery

            case .readingQuery:
                parser.unsafeAdvance()
                query = try! parser.read(until: "#", throwOnOverflow: false)
                state = .finished

            case .finished:
                break
            }
        }

        self.string = string
        self._scheme = scheme
        self._host = host
        self._port = port
        self._path = path
        self._query = query
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    private static let hostEndSet: Set<Unicode.Scalar> = Set(":/?")
    private static let portEndSet: Set<Unicode.Scalar> = Set("/?")
}

extension HBParameters {
    init(fromQuery query: Parser?) {
        guard var query = query else {
            self.parameters = [:]
            return
        }
        let queries: [Parser] = query.split(separator: "&")
        let queryKeyValues = queries.map { query -> (key: Substring, value: Substring) in
            do {
                var query = query
                let key = try query.read(until: "=")
                query.unsafeAdvance()
                if query.reachedEnd() {
                    return (key: key.string[...], value: "")
                } else {
                    let value = query.readUntilTheEnd()
                    return (key: key.string[...], value: value.string[...].removingPercentEncoding)
                }
            } catch {
                return (key: query.string[...], value: "")
            }
        }
        self.parameters = [Substring: Substring].init(queryKeyValues) { lhs, _ in lhs }
    }
}

