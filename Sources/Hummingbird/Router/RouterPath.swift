//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Split router path into components
public struct RouterPath: Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public struct Element: Equatable, Sendable, CustomStringConvertible {
        package enum _Internal: Equatable, Sendable {
            case path(Substring)
            case capture(Substring)
            case prefixCapture(suffix: Substring, parameter: Substring) // *.jpg
            case suffixCapture(prefix: Substring, parameter: Substring) // file.*
            case wildcard
            case prefixWildcard(Substring) // *.jpg
            case suffixWildcard(Substring) // file.*
            case recursiveWildcard
            case null
        }

        package let value: _Internal
        init(_ value: _Internal) {
            self.value = value
        }

        init(_ string: Substring) {
            if string.first == ":" {
                self = .capture(string.dropFirst())
            } else if string.first == "{" {
                let parameter = string.dropFirst(1)
                if let closingParethesis = parameter.firstIndex(of: "}") {
                    let charAfterClosingParethesis = parameter.index(after: closingParethesis)
                    if charAfterClosingParethesis == parameter.endIndex {
                        self = .capture(parameter[..<closingParethesis])
                    } else {
                        self = .prefixCapture(suffix: parameter[charAfterClosingParethesis...], parameter: parameter[..<closingParethesis])
                    }
                } else {
                    self = .path(string)
                }
            } else if string.last == "}" {
                let parameter = string.dropLast()
                if let openingParenthesis = parameter.lastIndex(of: "{"), openingParenthesis != parameter.startIndex {
                    let charAfterOpeningParenthesis = parameter.index(after: openingParenthesis)
                    self = .suffixCapture(prefix: parameter[..<openingParenthesis], parameter: parameter[charAfterOpeningParenthesis...])
                } else {
                    self = .path(string)
                }
            } else if string == "*" {
                self = .wildcard
            } else if string == "**" {
                self = .recursiveWildcard
            } else if string.first == "*" {
                self = .prefixWildcard(string.dropFirst())
            } else if string.last == "*" {
                self = .suffixWildcard(string.dropLast())
            } else {
                self = .path(string)
            }
        }

        /// Match to string
        public static func path(_ path: Substring) -> Self { .init(.path(path)) }
        /// Store parameter
        public static func capture(_ parameter: Substring) -> Self { .init(.capture(parameter)) }
        /// Match suffix and capture prefix eg *.jpg
        public static func prefixCapture(suffix: Substring, parameter: Substring) -> Self {
            .init(.prefixCapture(suffix: suffix, parameter: parameter))
        }

        /// Match prefix and capture suffix eg file.*
        public static func suffixCapture(prefix: Substring, parameter: Substring) -> Self {
            .init(.suffixCapture(prefix: prefix, parameter: parameter))
        }

        /// Always match
        public static var wildcard: Self { .init(.wildcard) }
        /// Match suffix eg *.jpg
        public static func prefixWildcard(_ suffix: Substring) -> Self { .init(.prefixWildcard(suffix)) }
        /// Match prefix eg file.*
        public static func suffixWildcard(_ prefix: Substring) -> Self { .init(.suffixWildcard(prefix)) }
        /// Always match and everything after
        public static var recursiveWildcard: Self { .init(.recursiveWildcard) }
        ///
        public static var null: Self { .init(.null) }

        /// A textual representation of the RouterPath component
        public var description: String {
            switch self.value {
            case .path(let path):
                return String(path)
            case .capture(let parameter):
                return "{\(parameter)}"
            case .prefixCapture(let suffix, let parameter):
                return "{\(parameter)}\(suffix)"
            case .suffixCapture(let prefix, let parameter):
                return "\(prefix){\(parameter)}"
            case .wildcard:
                return "*"
            case .prefixWildcard(let suffix):
                return "*\(suffix)"
            case .suffixWildcard(let prefix):
                return "\(prefix)*"
            case .recursiveWildcard:
                return "**"
            case .null:
                return "!"
            }
        }

        /// Match element with string
        static func ~= (lhs: Element, rhs: some StringProtocol) -> Bool {
            switch lhs.value {
            case .path(let lhs):
                return lhs == rhs
            case .capture:
                return true
            case .prefixCapture(let suffix, _):
                return rhs.hasSuffix(suffix)
            case .suffixCapture(let prefix, _):
                return rhs.hasPrefix(prefix)
            case .wildcard:
                return true
            case .prefixWildcard(let suffix):
                return rhs.hasSuffix(suffix)
            case .suffixWildcard(let prefix):
                return rhs.hasPrefix(prefix)
            case .recursiveWildcard:
                return true
            case .null:
                return false
            }
        }

        /// Element a path String
        static func == (lhs: Element, rhs: some StringProtocol) -> Bool {
            switch lhs.value {
            case .path(let lhs):
                return lhs == rhs
            default:
                return false
            }
        }

        /// Return lowercased version of RouterPath component
        public func lowercased() -> Self {
            switch self.value {
            case .path(let path):
                .path(path.lowercased()[...])
            case .prefixCapture(let suffix, let parameter):
                .prefixCapture(suffix: suffix.lowercased()[...], parameter: parameter)
            case .suffixCapture(let prefix, let parameter):
                .suffixCapture(prefix: prefix.lowercased()[...], parameter: parameter)
            case .prefixWildcard(let suffix):
                .prefixWildcard(suffix)
            case .suffixWildcard(let prefix):
                .suffixWildcard(prefix)
            default:
                self
            }
        }
    }

    /// Array of RouterPath elements
    public let components: [Element]
    /// A textual representation of the RouterPath
    public let description: String

    internal init(components: [Element]) {
        self.components = components
        self.description = "/\(self.components.map(\.description).joined(separator: "/"))"
    }

    /// Initialize RouterPath from URI string
    public init(_ value: String) {
        let split = value.split(separator: "/", omittingEmptySubsequences: true)
        self.init(components: split.map { .init($0) })
    }

    /// Initialize RouterPath from String literal
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// Return lowercased version of RouterPath
    public func lowercased() -> Self {
        .init(components: self.map { $0.lowercased() })
    }

    /// Combine two RouterPaths
    public func appendPath(_ path: RouterPath) -> Self {
        .init(components: self.components + path.components)
    }
}

extension RouterPath: Collection {
    public func index(after i: Int) -> Int {
        return self.components.index(after: i)
    }

    public subscript(_ index: Int) -> RouterPath.Element {
        return self.components[index]
    }

    public var startIndex: Int { self.components.startIndex }
    public var endIndex: Int { self.components.endIndex }
}
