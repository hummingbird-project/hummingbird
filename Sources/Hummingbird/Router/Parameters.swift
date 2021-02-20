/// Store for parameters key, value pairs extracted from URI
public struct HBParameters {
    internal var parameters: [Substring: Substring]

    init() {
        self.parameters = [:]
    }

    /// Return parameter with specified id
    /// - Parameter s: parameter id
    public func get(_ s: String) -> String? {
        return self.parameters[s[...]].map { String($0) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        return self.parameters[s[...]].map { T(String($0)) } ?? nil
    }

    /// Set parameter
    /// - Parameters:
    ///   - s: parameter id
    ///   - value: parameter value
    mutating func set(_ s: Substring, value: Substring) {
        self.parameters[s] = value
    }

    public subscript(_ s: String) -> String? {
        return self.parameters[s[...]].map { String($0) }
    }

    public subscript(_ s: Substring) -> String? {
        return self.parameters[s].map { String($0) }
    }

    /// number of parameters
    public var count: Int { return self.parameters.count }
}
