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
public struct RouterPath: Sendable, ExpressibleByStringLiteral, CustomStringConvertible, Collection {
    public enum Element: Sendable, Equatable, CustomStringConvertible {
        case path(Substring)
        case capture(Substring)
        case prefixCapture(suffix: Substring, parameter: Substring) // *.jpg
        case suffixCapture(prefix: Substring, parameter: Substring) // file.*
        case wildcard
        case prefixWildcard(Substring) // *.jpg
        case suffixWildcard(Substring) // file.*
        case recursiveWildcard

        public var description: String {
            switch self {
            case .path(let path):
                return String(path)
            case .capture(let parameter):
                return "${\(parameter)}"
            case .prefixCapture(let suffix, let parameter):
                return "${\(parameter)}\(suffix)"
            case .suffixCapture(let prefix, let parameter):
                return "\(prefix)${\(parameter)}"
            case .wildcard:
                return "*"
            case .prefixWildcard(let suffix):
                return "*\(suffix)"
            case .suffixWildcard(let prefix):
                return "\(prefix)*"
            case .recursiveWildcard:
                return "**"
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

    public var description: String {
        self.components.map(\.description).joined(separator: "/")
    }

    func matchAll<Context: HBRequestContext>(_ context: Context) -> Context? {
        if self.components.count != context.coreContext.remainingPathComponents.count {
            if case .recursiveWildcard = self.components.last {
                if self.components.count > context.coreContext.remainingPathComponents.count + 1 {
                    return nil
                }
            } else {
                return nil
            }
        }
        return self.match(context)
    }

    func matchPrefix<Context: HBRequestContext>(_ context: Context) -> Context? {
        if self.components.count > context.coreContext.remainingPathComponents.count {
            return nil
        }
        return self.match(context)
    }

    private func match<Context: HBRequestContext>(_ context: Context) -> Context? {
        var pathIterator = context.coreContext.remainingPathComponents.makeIterator()
        var context = context
        for component in self.components {
            switch component {
            case .path(let lhs):
                if lhs != pathIterator.next()! {
                    return nil
                }
            case .capture(let key):
                context.coreContext.parameters.set(key, value: pathIterator.next()!)

            case .prefixCapture(let suffix, let key):
                let pathComponent = pathIterator.next()!
                if pathComponent.hasSuffix(suffix) {
                    context.coreContext.parameters.set(key, value: pathComponent.dropLast(suffix.count))
                } else {
                    return nil
                }
            case .suffixCapture(let prefix, let key):
                let pathComponent = pathIterator.next()!
                if pathComponent.hasPrefix(prefix) {
                    context.coreContext.parameters.set(key, value: pathComponent.dropFirst(prefix.count))
                } else {
                    return nil
                }
            case .wildcard:
                break
            case .prefixWildcard(let suffix):
                if pathIterator.next()!.hasSuffix(suffix) {
                } else {
                    return nil
                }
            case .suffixWildcard(let prefix):
                if pathIterator.next()!.hasPrefix(prefix) {
                } else {
                    return nil
                }
            case .recursiveWildcard:
                var paths = pathIterator.next().map { [$0] } ?? []
                while let pathComponent = pathIterator.next() {
                    paths.append(pathComponent)
                }
                context.coreContext.parameters.setCatchAll(paths.joined(separator: "/")[...])
                context.coreContext.remainingPathComponents = []
                return context
            }
        }
        context.coreContext.remainingPathComponents = context.coreContext.remainingPathComponents.dropFirst(self.components.count)
        return context
    }
}

extension RouterPath {
    public func index(after i: Int) -> Int {
        return self.components.index(after: i)
    }

    public subscript(_ index: Int) -> RouterPath.Element {
        return self.components[index]
    }

    public var startIndex: Int { self.components.startIndex }
    public var endIndex: Int { self.components.endIndex }
}
