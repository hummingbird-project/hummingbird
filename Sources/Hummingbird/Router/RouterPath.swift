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
    public enum Element: Equatable, Sendable, CustomStringConvertible {
        case path(Substring)
        case capture(Substring)
        case prefixCapture(suffix: Substring, parameter: Substring) // *.jpg
        case suffixCapture(prefix: Substring, parameter: Substring) // file.*
        case wildcard
        case prefixWildcard(Substring) // *.jpg
        case suffixWildcard(Substring) // file.*
        case recursiveWildcard
        case null

        public var description: String {
            switch self {
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

        static func ~= (lhs: Element, rhs: some StringProtocol) -> Bool {
            switch lhs {
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

        static func == (lhs: Element, rhs: some StringProtocol) -> Bool {
            switch lhs {
            case .path(let lhs):
                return lhs == rhs
            default:
                return false
            }
        }

        public func lowercased() -> Self {
            switch self {
            case .path(let path):
                .path(path.lowercased()[...])
            case .prefixCapture(let suffix, let parameter):
                .prefixCapture(suffix: suffix.lowercased()[...], parameter: parameter)
            case .suffixCapture(let prefix, let parameter):
                .suffixCapture(prefix: prefix.lowercased()[...], parameter: parameter)
            default:
                self
            }
        }
    }

    public let components: [Element]
    public let description: String

    public init(_ value: String) {
        let split = value.split(separator: "/", omittingEmptySubsequences: true)
        self.components = split.map { component in
            if component.first == ":" {
                return .capture(component.dropFirst())
            } else if component.first == "{" {
                let parameter = component.dropFirst(1)
                if let closingParethesis = parameter.firstIndex(of: "}") {
                    let charAfterClosingParethesis = parameter.index(after: closingParethesis)
                    if charAfterClosingParethesis == parameter.endIndex {
                        return .capture(parameter[..<closingParethesis])
                    } else {
                        return .prefixCapture(suffix: parameter[charAfterClosingParethesis...], parameter: parameter[..<closingParethesis])
                    }
                } else {
                    return .path(component)
                }
            } else if component.last == "}" {
                let parameter = component.dropLast()
                if let openingParenthesis = parameter.lastIndex(of: "{"), openingParenthesis != parameter.startIndex {
                    let charAfterOpeningParenthesis = parameter.index(after: openingParenthesis)
                    return .suffixCapture(prefix: parameter[..<openingParenthesis], parameter: parameter[charAfterOpeningParenthesis...])
                }
                return .path(component)
            } else if component == "*" {
                return .wildcard
            } else if component == "**" {
                return .recursiveWildcard
            } else if component.first == "*" {
                return .prefixWildcard(component.dropFirst())
            } else if component.last == "*" {
                return .suffixWildcard(component.dropLast())
            } else {
                return .path(component)
            }
        }
        self.description = "/\(self.components.map(\.description).joined(separator: "/"))"
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    internal init(components: [Element]) {
        self.components = components
        self.description = "/\(self.components.map(\.description).joined(separator: "/"))"
    }

    public func lowercased() -> Self {
        .init(components: self.map { $0.lowercased() })
    }

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
