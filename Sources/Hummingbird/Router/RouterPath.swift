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
struct RouterPath: ExpressibleByStringLiteral {
    enum Element: Equatable {
        case path(Substring)
        case parameter(Substring)
        case wildcard
        case recursiveWildcard
        case null

        static func ~= <S: StringProtocol>(lhs: Element, rhs: S) -> Bool {
            switch lhs {
            case .path(let lhs):
                return lhs == rhs
            case .parameter:
                return true
            case .wildcard:
                return true
            case .recursiveWildcard:
                return true
            case .null:
                return false
            }
        }

        static func == <S: StringProtocol>(lhs: Element, rhs: S) -> Bool {
            switch lhs {
            case .path(let lhs):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    let components: [Element]

    init(_ value: String) {
        let split = value.split(separator: "/", omittingEmptySubsequences: true)
        self.components = split.map { component in
            if component.first == ":" {
                return .parameter(component.dropFirst())
            } else if component == "*" {
                return .wildcard
            } else if component == "**" {
                return .recursiveWildcard
            } else {
                return .path(component)
            }
        }
    }

    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension RouterPath: Collection {
    func index(after i: Int) -> Int {
        return self.components.index(after: i)
    }

    subscript(_ index: Int) -> RouterPath.Element {
        return self.components[index]
    }

    var startIndex: Int { self.components.startIndex }
    var endIndex: Int { self.components.endIndex }
}
