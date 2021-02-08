/// Store for parameters extracted from Request URI
public struct HBParameters {
    var parameters: [Substring: Substring]

    init() {
        self.parameters = [:]
    }

    /// Return parameter with specified id
    /// - Parameter s: parameter id
    public func get(_ s: Substring) -> Substring? {
        return self.parameters[s[...]]
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func get<T: LosslessStringConvertible>(_ s: Substring, as: T.Type) -> T? {
        return self.parameters[s[...]].map { T(String($0)) } ?? nil
    }

    /// Set parameter
    /// - Parameters:
    ///   - s: parameter id
    ///   - value: parameter value
    public mutating func set(_ s: Substring, value: Substring) {
        self.parameters[s] = value
    }

    /// number of parameters
    public var count: Int { return self.parameters.count }
}
