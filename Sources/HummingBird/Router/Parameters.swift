
struct Parameters {
    var parameters: [Substring: Substring]
    
    init() {
        parameters = [:]
    }
    
    func get(_ s: Substring) -> Substring? {
        return parameters[s[...]]
    }
    
    func get<T: LosslessStringConvertible>(_ s: Substring, as: T.Type) -> T? {
        return parameters[s[...]].map { T(String($0)) } ?? nil
    }
    
    mutating func set(_ s: Substring, value: Substring) {
        parameters[s] = value
    }
}
