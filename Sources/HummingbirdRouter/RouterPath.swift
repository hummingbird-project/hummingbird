//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import Hummingbird

#if canImport(FoundationEssentials)
internal import FoundationEssentials
#else
internal import Foundation
#endif

extension RouterPath {
    func matchAll<Context: RouterRequestContext>(_ context: Context) -> Context? {
        if self.components.count != context.routerContext.remainingPathComponents.count {
            if case .recursiveWildcard = self.components.last?.value {
                if self.components.count > context.routerContext.remainingPathComponents.count + 1 {
                    return nil
                }
            } else {
                return nil
            }
        }
        return self.match(context)
    }

    @usableFromInline
    func matchPrefix<Context: RouterRequestContext>(_ context: Context) -> Context? {
        if self.components.count > context.routerContext.remainingPathComponents.count {
            return nil
        }
        return self.match(context)
    }

    private func match<Context: RouterRequestContext>(_ context: Context) -> Context? {
        var pathIterator = context.routerContext.remainingPathComponents.makeIterator()
        var context = context
        for component in self.components {
            switch component.value {
            case .path(let lhs):
                if context.routerContext.caseInsensitive {
                    if !lhs._routerCaseInsensitiveCompare(pathIterator.next()!) {
                        return nil
                    }
                } else {
                    if lhs != pathIterator.next()! {
                        return nil
                    }
                }
            case .capture(let key):
                context.coreContext.parameters[key] = pathIterator.next()!
            case .prefixCapture(let suffix, let key):
                let pathComponent = pathIterator.next()!
                let matches =
                    if context.routerContext.caseInsensitive {
                        pathComponent.hasCaseInsensitiveSuffix(suffix)
                    } else {
                        pathComponent.hasSuffix(suffix)
                    }
                if matches {
                    context.coreContext.parameters[key] = pathComponent.dropLast(suffix.count)
                } else {
                    return nil
                }
            case .suffixCapture(let prefix, let key):
                let pathComponent = pathIterator.next()!
                let matches =
                    if context.routerContext.caseInsensitive {
                        pathComponent.hasCaseInsensitivePrefix(prefix)
                    } else {
                        pathComponent.hasPrefix(prefix)
                    }
                if matches {
                    context.coreContext.parameters[key] = pathComponent.dropFirst(prefix.count)
                } else {
                    return nil
                }
            case .wildcard:
                break
            case .prefixWildcard(let suffix):
                let matches =
                    if context.routerContext.caseInsensitive {
                        pathIterator.next()!.hasCaseInsensitiveSuffix(suffix)
                    } else {
                        pathIterator.next()!.hasSuffix(suffix)
                    }
                if !matches {
                    return nil
                }
            case .suffixWildcard(let prefix):
                let matches =
                    if context.routerContext.caseInsensitive {
                        pathIterator.next()!.hasCaseInsensitivePrefix(prefix)
                    } else {
                        pathIterator.next()!.hasPrefix(prefix)
                    }
                if !matches {
                    return nil
                }
            case .recursiveWildcard:
                var paths = pathIterator.next().map { [$0] } ?? []
                while let pathComponent = pathIterator.next() {
                    paths.append(pathComponent)
                }
                context.coreContext.parameters.setCatchAll(paths.joined(separator: "/")[...])
                context.routerContext.remainingPathComponents = []
                return context
            case .null:
                return nil
            }
        }
        context.routerContext.remainingPathComponents = context.routerContext.remainingPathComponents.dropFirst(self.components.count)
        return context
    }
}

extension StringProtocol {
    func hasCaseInsensitivePrefix<Prefix>(_ prefix: Prefix) -> Bool where Prefix: StringProtocol {
        guard prefix.count <= self.count else { return false }
        let prefixEndIndex = self.index(self.startIndex, offsetBy: prefix.count)
        return prefix._routerCaseInsensitiveCompare(self[..<prefixEndIndex])
    }

    func hasCaseInsensitiveSuffix<Suffix>(_ suffix: Suffix) -> Bool where Suffix: StringProtocol {
        guard suffix.count <= self.count else { return false }
        let suffixStartIndex = self.index(self.endIndex, offsetBy: -suffix.count)
        return suffix._routerCaseInsensitiveCompare(self[suffixStartIndex...])
    }
}
