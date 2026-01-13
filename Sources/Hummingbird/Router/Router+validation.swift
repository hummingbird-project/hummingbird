//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
        try self.trie.root.validate()
    }
}

extension RouterPathTrieBuilder.Node {
    func validate(_ root: String = "") throws {
        let sortedChildren = children.sorted { $0.key.priority > $1.key.priority }
        if sortedChildren.count > 1 {
            for index in 1..<sortedChildren.count {
                let exampleElement =
                    switch sortedChildren[index].key.value {
                    case .path(let path):
                        String(path)
                    case .capture:
                        UUID().uuidString
                    case .prefixCapture(let suffix, _):
                        "\(UUID().uuidString)\(suffix)"
                    case .suffixCapture(let prefix, _):
                        "\(prefix)/\(UUID().uuidString)"
                    case .wildcard:
                        UUID().uuidString
                    case .prefixWildcard(let suffix):
                        "\(UUID().uuidString)\(suffix)"
                    case .suffixWildcard(let prefix):
                        "\(prefix)/\(UUID().uuidString)"
                    case .recursiveWildcard:
                        UUID().uuidString
                    case .null:
                        ""
                    }
                // test path element against all the previous trie entries in this node
                for trieEntry in sortedChildren[0..<index] {
                    if case trieEntry.key = exampleElement {
                        throw RouterValidationError(
                            path: "\(root)/\(sortedChildren[index].key)",
                            override: "\(root)/\(trieEntry.key)"
                        )
                    }
                }

            }
        }

        for child in self.children {
            try child.validate("\(root)/\(child.key)")
        }
    }
}

/// Router validation error
public struct RouterValidationError: Error, CustomStringConvertible, Equatable {
    let path: RouterPath
    let override: RouterPath

    package init(path: RouterPath, override: RouterPath) {
        self.path = path
        self.override = override
    }

    public var description: String {
        "Route \(override) overrides \(path)"
    }
}
