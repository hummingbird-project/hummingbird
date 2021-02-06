import HummingbirdCore

/// Route requests to handlers based on request URI. Uses a Trie to select handler
struct TrieRouter: HBRouter {
    var trie: RouterPathTrie<HBEndpointResponder>

    public init() {
        self.trie = RouterPathTrie()
    }

    /// Add route to router
    /// - Parameters:
    ///   - path: URI path
    ///   - method: http method
    ///   - responder: handler to call
    public func add(_ path: String, method: HTTPMethod, responder: HBResponder) {
        self.trie.addEntry(.init(path), value: HBEndpointResponder()) { node in
            node.value!.addResponder(for: method, responder: responder)
        }
    }

    func endpoint(_ path: String) -> HBEndpointResponder? {
        trie.getValueAndParameters(path)?.value
    }
    
    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: HBRequest) -> EventLoopFuture<HBResponse> {
        let path = "\(request.uri.path)"
        guard let result = trie.getValueAndParameters(path) else {
            return request.eventLoop.makeFailedFuture(HBHTTPError(.notFound))
        }
        if result.parameters.count > 0 {
            request.parameters = result.parameters
        }
        return result.value.respond(to: request)
    }
}

/// URI Path Trie
struct RouterPathTrie<Value> {
    var root: Node

    init() {
        self.root = Node(key: .null, output: nil)
    }

    func addEntry(_ entry: RouterPath, value: @autoclosure () -> Value, onAdd: (Node) -> () = { _ in }) {
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
    class Node {
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
            children.append(node)
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
