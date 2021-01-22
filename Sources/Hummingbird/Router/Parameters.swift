/// parameter map, extracted from Request URI
public struct HBParameters {
    var parameters: [Substring: Substring]
    
    init() {
        parameters = [:]
    }
    
    public func get(_ s: Substring) -> Substring? {
        return parameters[s[...]]
    }
    
    public func get<T: LosslessStringConvertible>(_ s: Substring, as: T.Type) -> T? {
        return parameters[s[...]].map { T(String($0)) } ?? nil
    }
    
    public mutating func set(_ s: Substring, value: Substring) {
        parameters[s] = value
    }
    
    public var count: Int { return parameters.count }
}
