/// Route requests to handlers based on request URI. Uses a Trie to select handler
public struct TrieRouter: Router {
    var trie: RouterPathTrie<RequestResponder>
    
    public init() {
        self.trie = RouterPathTrie()
    }

    /// Add route to router
    /// - Parameters:
    ///   - path: URI path
    ///   - method: http method
    ///   - responder: handler to call
    public func add(_ path: String, method: HTTPMethod, responder: RequestResponder) {
        // add method at beginning of Path to differentiate between methods
        let path = "\(method.rawValue)/\(path)"
        trie.addEntry(.init(path), value: responder)
    }

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let path = "\(request.method.rawValue)/\(request.uri.path)"
        guard let result = trie.getValueAndParameters(path) else {
            return request.eventLoop.makeFailedFuture(HTTPError(.notFound))
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
        root = Node(key: .null, output: nil)
    }
    
    func addEntry(_ entry: RouterPath, value: Value) {
        var node = root
        for key in entry {
            node = node.addChild(key: key, output: nil)
        }
        node.value = value
    }
    
    func getValueAndParameters(_ path: String) -> (value: Value, parameters: Parameters)? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        var parameters = Parameters()
        var node = root
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
            return children.first { $0.key == key }
        }
        
        func getChild(_ key: Substring) -> Node? {
            return children.first { $0.key == key }
        }
    }
}
