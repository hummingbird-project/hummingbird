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
struct RouterPathTrieBuilder<Value: Sendable> {
    var root: Node

    init() {
        self.root = Node(key: .null, output: nil)
    }

    /// Add Entry to Trie
    /// - Parameters:
    ///   - entry: Path for entry
    ///   - value: Value to add to this path if one does not exist already
    ///   - onAdd: How to edit the value at this path
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

    func build() -> RouterPathTrie<Value> {
        .init(root: self.root.build())
    }

    func forEach(_ process: (Node) throws -> Void) rethrows {
        try self.root.forEach(process)
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

        func build() -> RouterPathTrie<Value>.Node {
            return .init(key: self.key, value: self.value, children: self.children.map { $0.build() })
        }

        func forEach(_ process: (Node) throws -> Void) rethrows {
            try process(self)
            for node in self.children {
                try node.forEach(process)
            }
        }
    }
}

import NIOCore

public struct BinaryRouterResponder<Context: BaseRequestContext>: HTTPResponder {
    let trie: BinaryTrie<EndpointResponders<Context>>
    let notFoundResponder: any HTTPResponder<Context>
    let options: RouterOptions

    init(
        context: Context.Type,
        trie: RouterPathTrie<EndpointResponders<Context>>,
        options: RouterOptions,
        notFoundResponder: any HTTPResponder<Context>
    ) throws {
        self.trie = try BinaryTrie(base: trie)
        self.options = options
        self.notFoundResponder = notFoundResponder
    }

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: Request, context: Context) async throws -> Response {
        let path: String
        if self.options.contains(.caseInsensitive) {
            path = request.uri.path.lowercased()
        } else {
            path = request.uri.path
        }
        guard 
            let (responderChain, parameters) = trie.resolve(path),
            let responder = responderChain.getResponder(for: request.method)
        else {
            return try await self.notFoundResponder.respond(to: request, context: context)
        }
        var context = context
        context.coreContext.parameters = parameters
        // store endpoint path in request (mainly for metrics)
        context.coreContext.endpointPath.value = responderChain.path
        return try await responder.respond(to: request, context: context)
    }
}

/// Trie used by Router responder
struct RouterPathTrie<Value: Sendable>: Sendable {
    let root: Node

    /// Initialise RouterPathTrie
    /// - Parameter root: Root node of trie
    init(root: Node) {
        self.root = root
    }

    /// Get value from trie and any parameters from capture nodes
    /// - Parameter path: Path to process
    /// - Returns: value and parameters
    func getValueAndParameters(_ path: String) -> (value: Value, parameters: Parameters?)? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters: Parameters?
        var node = self.root
        for component in pathComponents {
            if let childNode = node.getChild(component) {
                node = childNode
                switch node.key {
                case .capture(let key):
                    parameters.set(key, value: component)
                case .prefixCapture(let suffix, let key):
                    parameters.set(key, value: component.dropLast(suffix.count))
                case .suffixCapture(let prefix, let key):
                    parameters.set(key, value: component.dropFirst(prefix.count))
                case .recursiveWildcard:
                    parameters.setCatchAll(path[component.startIndex..<path.endIndex])
                default:
                    break
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

    /// Internally used Node to describe static trie
    struct Node: Sendable {
        let key: RouterPath.Element
        let children: [Node]
        let value: Value?

        init(key: RouterPath.Element, value: Value?, children: [Node]) {
            self.key = key
            self.value = value
            self.children = children
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

extension Optional<Parameters> {
    fileprivate mutating func set(_ s: Substring, value: Substring) {
        switch self {
        case .some(var parameters):
            parameters[s] = value
            self = .some(parameters)
        case .none:
            self = .some(.init(.init([(s, value)])))
        }
    }

    fileprivate mutating func setCatchAll(_ value: Substring) {
        switch self {
        case .some(var parameters):
            parameters.setCatchAll(value)
            self = .some(parameters)
        case .none:
            self = .some(.init(.init([(Parameters.recursiveCaptureKey, value)])))
        }
    }
}
