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

/// URI Path Trie
struct RouterPathTrie<Value> {
    var root: Node

    init() {
        self.root = Node(key: .null, output: nil)
    }

    func addEntry(_ entry: RouterPath, value: @autoclosure () -> Value, onAdd: (Node) -> Void = { _ in }) {
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

    func getValueAndParameters(_ path: String) -> (value: Value, parameters: HBParameters)? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters = HBParameters()
        var node = self.root
        for component in pathComponents {
            if let childNode = node.getChild(component) {
                node = childNode
                if case .parameter(let key) = node.key {
                    parameters.set(key, value: component)
                }
            } else if case .recursiveWildcard = node.key {
            } else {
                return nil
            }
        }
        if let value = node.value {
            return (value: value, parameters: parameters)
        }
        return nil
    }

    /// Trie Node. Each node represents one component of a URI path
    final class Node {
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
            return self.children.first { $0.key == key }
        }

        func getChild(_ key: Substring) -> Node? {
            if let child = self.children.first(where: { $0.key == key }) {
                return child
            }
            return self.children.first { $0.key ~= key }
        }
    }
}
