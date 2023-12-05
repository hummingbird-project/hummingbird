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
public struct RouterPath: Sendable, ExpressibleByStringLiteral {
    public enum Element: Equatable, Sendable {
        case path(Substring)
        case capture(Substring)
        case prefixCapture(suffix: Substring, parameter: Substring) // *.jpg
        case suffixCapture(prefix: Substring, parameter: Substring) // file.*
        case wildcard
        case prefixWildcard(Substring) // *.jpg
        case suffixWildcard(Substring) // file.*
        case recursiveWildcard
        case null

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
    }

    public let components: [Element]

    public init(_ value: String) {
        let split = value.split(separator: "/", omittingEmptySubsequences: true)
        self.components = split.map { component in
            if component.first == ":" {
                return .capture(component.dropFirst())
            } else if component.first == "$", component.count > 1, component[component.index(after: component.startIndex)] == "{" {
                let parameter = component.dropFirst(2)
                if let closingParethesis = parameter.firstIndex(of: "}") {
                    let charAfterClosingParethesis = parameter.index(after: closingParethesis)
                    return .prefixCapture(suffix: parameter[charAfterClosingParethesis...], parameter: parameter[..<closingParethesis])
                } else {
                    return .path(component)
                }
            } else if component.last == "}" {
                let parameter = component.dropLast()
                if let openingParenthesis = parameter.lastIndex(of: "{"), openingParenthesis != parameter.startIndex {
                    let dollar = component.index(before: openingParenthesis)
                    if component[dollar] == "$" {
                        let charAfterOpeningParenthesis = parameter.index(after: openingParenthesis)
                        return .suffixCapture(prefix: parameter[..<dollar], parameter: parameter[charAfterOpeningParenthesis...])
                    }
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
    }

    public init(stringLiteral value: String) {
        self.init(value)
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
