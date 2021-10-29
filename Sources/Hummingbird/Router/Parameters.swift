//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Store for parameters key, value pairs extracted from URI
public struct HBParameters: HBSendable {
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

    /// Return parameter with specified id
    /// - Parameter s: parameter id
    public func require(_ s: String) throws -> String {
        guard let param = self.parameters[s[...]].map({ String($0) }) else {
            throw HBHTTPError(.badRequest)
        }
        return param
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func require<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> T {
        guard let param = self.parameters[s[...]],
              let result = T(String(param))
        else {
            throw HBHTTPError(.badRequest)
        }
        return result
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
}

extension HBParameters: Collection {
    public typealias Index = Dictionary<Substring, Substring>.Index
    public var startIndex: Index { self.parameters.startIndex }
    public var endIndex: Index { self.parameters.endIndex }
    public subscript(_ index: Index) -> Dictionary<Substring, Substring>.Element { return self.parameters[index] }
    public func index(after index: Index) -> Index { self.parameters.index(after: index) }
}

extension HBParameters: CustomStringConvertible {
    public var description: String {
        String(describing: self.parameters)
    }
}
