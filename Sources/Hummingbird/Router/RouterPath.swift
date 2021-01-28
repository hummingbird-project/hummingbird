/// Split router path into components
struct RouterPath: ExpressibleByStringLiteral {
    enum Element: Equatable {
        case path(Substring)
        case parameter(Substring)
        case wildcard
        case null

        static func == <S: StringProtocol>(lhs: Element, rhs: S) -> Bool {
            switch lhs {
            case .path(let lhs):
                return lhs == rhs
            case .parameter:
                return true
            case .wildcard:
                return true
            default:
                return false
            }
        }
    }

    let components: [Element]

    init(_ value: String) {
        let split = value.split(separator: "/", omittingEmptySubsequences: true)
        self.components = split.map { component in
            if component.first == ":" {
                return .parameter(component.dropFirst())
            } else if component == "*" {
                return .wildcard
            } else {
                return .path(component)
            }
        }
    }

    init(stringLiteral value: String) {
        self.init(value)
    }
}

extension RouterPath: Collection {
    func index(after i: Int) -> Int {
        return self.components.index(after: i)
    }

    subscript(_ index: Int) -> RouterPath.Element {
        return self.components[index]
    }

    var startIndex: Int { self.components.startIndex }
    var endIndex: Int { self.components.endIndex }
}
