//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore

/// URI Path Trie Builder
@_spi(Internal) public struct RouterPathTrieBuilder<Value: Sendable> {
    @usableFromInline
    var root: Node

    @_spi(Internal) public init() {
        self.root = Node(key: .null, output: nil)
    }

    /// Add Entry to Trie
    /// - Parameters:
    ///   - entry: Path for entry
    ///   - value: Value to add to this path if one does not exist already
    ///   - onAdd: How to edit the value at this path
    @_spi(Internal) public func addEntry(_ entry: RouterPath, value: @autoclosure () -> Value, onAdd: (Node) -> Void = { _ in }) {
        var node = self.root
        for key in entry {
            node = node.addChild(key: key, output: nil)
        }
        if node.value != nil {
            onAdd(node)
        } else {
            node.value = value()
            onAdd(node)
        }
    }

    @_spi(Internal) public func build() -> RouterTrie<Value> {
        .init(base: self)
    }

    func forEach(_ process: (Node) throws -> Void) rethrows {
        try self.root.forEach(process)
    }

    /// Trie Node. Each node represents one component of a URI path
    @_spi(Internal) public final class Node {
        let key: RouterPath.Element

        var children: [Node]

        var value: Value?

        init(key: RouterPath.Element, output: Value?) {
            self.key = key
            self.value = output
            self.children = []
        }

        func addChild(key: RouterPath.Element, output: Value?) -> Node {
            if let child = getChild(key) {
                return child
            }
            let node = Node(key: key, output: output)
            self.children.append(node)
            return node
        }

        func getChild(_ key: RouterPath.Element) -> Node? {
            self.children.first { $0.key == key }
        }

        func getChild(_ key: Substring) -> Node? {
            if let child = self.children.first(where: { $0.key == key }) {
                return child
            }
            return self.children.first { $0.key ~= key }
        }

        func forEach(_ process: (Node) throws -> Void) rethrows {
            try process(self)
            for node in self.children {
                try node.forEach(process)
            }
        }
    }
}
