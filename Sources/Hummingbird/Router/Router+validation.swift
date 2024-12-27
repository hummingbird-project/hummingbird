//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import HTTPTypes

extension Router {
    /// Route description
    public struct RouteDescription: CustomStringConvertible {
        /// Route path
        public let path: RouterPath
        /// Route method
        public let method: HTTPRequest.Method

        public var description: String { "\(method) \(path)" }
    }

    /// List of routes added to router
    public var routes: [RouteDescription] {
        let trieValues = self.trie.root.values()
        return trieValues.flatMap { endpoint in
            endpoint.value.methods.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { RouteDescription(path: endpoint.path, method: $0) }
        }
    }

    /// Validate router
    ///
    /// Verify that routes are not clashing
    public func validate() throws {
        func matching(routerPath: RouterPath, pathComponents: [String]) -> Bool {
            guard routerPath.count == pathComponents.count else { return false }
            for index in 0..<routerPath.count {
                if case routerPath[index] = pathComponents[index] {
                    continue
                }
                return false
            }
            return true
        }
        // get trie routes sorted in the way they will be evaluated after building the router
        let trieValues = self.trie.root.values().sorted { lhs, rhs in
            let count = min(lhs.path.count, rhs.path.count)
            for i in 0..<count {
                if lhs.path[i].priority < rhs.path[i].priority {
                    return false
                }
            }
            return true
        }
        guard trieValues.count > 1 else { return }
        for index in 1..<trieValues.count {
            // create path that will match this trie entry
            let pathComponents = trieValues[index].path.flatMap { element -> [String] in
                switch element.value {
                case .path(let path):
                    [String(path)]
                case .capture:
                    [UUID().uuidString]
                case .prefixCapture(let suffix, _):
                    ["\(UUID().uuidString)\(suffix)"]
                case .suffixCapture(let prefix, _):
                    ["\(prefix)/\(UUID().uuidString)"]
                case .wildcard:
                    [UUID().uuidString]
                case .prefixWildcard(let suffix):
                    ["\(UUID().uuidString)\(suffix)"]
                case .suffixWildcard(let prefix):
                    ["\(prefix)/\(UUID().uuidString)"]
                case .recursiveWildcard:
                    // can't think of a better way to do this at the moment except
                    // by creating path with many entries
                    (0..<20).map { _ in UUID().uuidString }
                case .null:
                    [""]
                }
            }
            // test path against all the previous trie entries
            for route in trieValues[0..<index] {
                if matching(routerPath: route.path, pathComponents: pathComponents) {
                    throw RouterValidationError(
                        path: trieValues[index].path,
                        override: route.path
                    )
                }
            }
        }
    }
}

/// Router validation error
public struct RouterValidationError: Error, CustomStringConvertible {
    let path: RouterPath
    let override: RouterPath

    public var description: String {
        "Route \(override) overrides \(path)"
    }
}
