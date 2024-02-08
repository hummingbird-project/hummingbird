//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore

/// HBParameters is a special case of FlatDictionary where both the key
/// and value types are Substrings. It is used for parameters extracted
/// from URIs
public typealias HBParameters = FlatDictionary<Substring, Substring>

public extension HBParameters {
    /// Return parameter with specified id
    /// - Parameter s: parameter id
    func get(_ s: String) -> String? {
        return self[s[...]].map { String($0) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        return self[s[...]].map { T(String($0)) } ?? nil
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func get<T: RawRepresentable>(_ s: String, as: T.Type) -> T? where T.RawValue == String {
        return self[s[...]].map { T(rawValue: String($0)) } ?? nil
    }

    /// Return parameter with specified id
    /// - Parameter s: parameter id
    func require(_ s: String) throws -> String {
        guard let param = self[s[...]].map({ String($0) }) else {
            throw HBHTTPError(.badRequest)
        }
        return param
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func require<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> T {
        guard let param = self[s[...]],
              let result = T(String(param))
        else {
            throw HBHTTPError(.badRequest)
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func require<T: RawRepresentable>(_ s: String, as: T.Type) throws -> T where T.RawValue == String {
        guard let param = self[s[...]],
              let result = T(rawValue: String(param))
        else {
            throw HBHTTPError(.badRequest)
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    func getAll(_ s: String) -> [String] {
        return self[values: s[...]].compactMap { String($0) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func getAll<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> [T] {
        return self[values: s[...]].compactMap { T(String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func getAll<T: RawRepresentable>(_ s: String, as: T.Type) -> [T] where T.RawValue == String {
        return self[values: s[...]].compactMap { T(rawValue: String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func requireAll<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> [T] {
        return try self[values: s[...]].map {
            guard let result = T(String($0)) else {
                throw HBHTTPError(.badRequest)
            }
            return result
        }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    func requireAll<T: RawRepresentable>(_ s: String, as: T.Type) throws -> [T] where T.RawValue == String {
        return try self[values: s[...]].map {
            guard let result = T(rawValue: String($0)) else {
                throw HBHTTPError(.badRequest)
            }
            return result
        }
    }
}

/// Catch all support
public extension HBParameters {
    static let recursiveCaptureKey: Substring = ":**:"

    ///  Return path elements caught by recursive capture
    func getCatchAll() -> [Substring] {
        return self[Self.recursiveCaptureKey].map { $0.split(separator: "/", omittingEmptySubsequences: true) } ?? []
    }

    /// Set path components caught by recursive capture
    /// - Parameters:
    ///   - value: parameter value
    mutating func setCatchAll(_ value: Substring) {
        guard !self.has(Self.recursiveCaptureKey) else { return }
        self[Self.recursiveCaptureKey] = value
    }
}
