
public struct TrieRouter: Router {
    var trie: PathTrie<RequestResponder>
    
    public init() {
        self.trie = PathTrie()
    }
    
    public func add(_ path: String, method: HTTPMethod, responder: RequestResponder) {
        // add method at beginning of Path to differentiate between methods
        let path = "\(method.rawValue)/\(path)"
        trie.addEntry(.init(path), value: responder)
    }
    
    public func respond(to request: Request) -> EventLoopFuture<Response> {
        let path = "\(request.method.rawValue)/\(request.uri.path)"
        guard let responder = trie.getValueAndParameters(path) else {
            return request.eventLoop.makeFailedFuture(HTTPError(.notFound))
        }
        return responder.value.respond(to: request)
    }
}

struct PathTrie<Value> {
    var root: Node

    init() {
        root = Node(key: .null, output: nil)
    }
    
    func addEntry(_ entry: Path, value: Value) {
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
    
    class Node {
        let key: Path.Element
        var children: [Node]
        var value: Value?
        
        init(key: Path.Element, output: Value?) {
            self.key = key
            self.value = output
            self.children = []
        }
        
        func addChild(key: Path.Element, output: Value?) -> Node {
            if let child = getChild(key) {
                return child
            }
            let node = Node(key: key, output: output)
            children.append(node)
            return node
        }
        
        func getChild(_ key: Path.Element) -> Node? {
            return children.first { $0.key == key }
        }
        
        func getChild(_ key: Substring) -> Node? {
            return children.first { $0.key == key }
        }
    }
}
