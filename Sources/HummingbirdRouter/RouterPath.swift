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

@_spi(Internal) import Hummingbird

extension RouterPath {
    func matchAll<Context: RouterRequestContext>(_ context: Context) -> Context? {
        if self.components.count != context.routerContext.remainingPathComponents.count {
            if case .recursiveWildcard = self.components.last {
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
            switch component {
            case .path(let lhs):
                if lhs != pathIterator.next()! {
                    return nil
                }
            case .capture(let key):
                context.coreContext.parameters[key] = pathIterator.next()!

            case .prefixCapture(let suffix, let key):
                let pathComponent = pathIterator.next()!
                if pathComponent.hasSuffix(suffix) {
                    context.coreContext.parameters[key] = pathComponent.dropLast(suffix.count)
                } else {
                    return nil
                }
            case .suffixCapture(let prefix, let key):
                let pathComponent = pathIterator.next()!
                if pathComponent.hasPrefix(prefix) {
                    context.coreContext.parameters[key] = pathComponent.dropFirst(prefix.count)
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
