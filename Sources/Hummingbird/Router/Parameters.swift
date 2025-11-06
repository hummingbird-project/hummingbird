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

public import HummingbirdCore

/// Parameters is a special case of FlatDictionary where both the key
/// and value types are Substrings. It is used for parameters extracted
/// from URIs
public typealias Parameters = FlatDictionary<Substring, Substring>

extension Parameters {
    /// Return parameter with specified id
    /// - Parameter s: parameter id
    public func get(_ s: String) -> String? {
        self[s[...]].map { String($0) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        self[s[...]].map { T(String($0)) } ?? nil
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    @_disfavoredOverload
    public func get<T: RawRepresentable>(_ s: String, as: T.Type) -> T? where T.RawValue == String {
        self[s[...]].map { T(rawValue: String($0)) } ?? nil
    }

    /// Return parameter with specified id
    /// - Parameter s: parameter id
    public func require(_ s: String) throws -> String {
        guard let param = self[s[...]].map({ String($0) }) else {
            throw HTTPError(.badRequest, message: "Expected parameter does not exist")
        }
        return param
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func require<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> T {
        guard let param = self[s[...]] else {
            throw HTTPError(.badRequest, message: "Expected parameter does not exist")
        }
        guard let result = T(String(param))
        else {
            throw HTTPError(.badRequest, message: "Parameter '\(param)' can not be converted to the expected type (\(T.self))")
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    @_disfavoredOverload
    public func require<T: RawRepresentable>(_ s: String, as: T.Type) throws -> T where T.RawValue == String {
        guard let param = self[s[...]] else {
            throw HTTPError(.badRequest, message: "Expected parameter does not exist")
        }
        guard let result = T(rawValue: String(param))
        else {
            throw HTTPError(.badRequest, message: "Parameter '\(param)' can not be converted to the expected type (\(T.self))")
        }
        return result
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    public func getAll(_ s: String) -> [String] {
        self[values: s[...]].compactMap { String($0) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func getAll<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> [T] {
        self[values: s[...]].compactMap { T(String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    @_disfavoredOverload
    public func getAll<T: RawRepresentable>(_ s: String, as: T.Type) -> [T] where T.RawValue == String {
        self[values: s[...]].compactMap { T(rawValue: String($0)) }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    public func requireAll<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> [T] {
        try self[values: s[...]].map {
            guard let result = T(String($0)) else {
                throw HTTPError(.badRequest, message: "One of the parameters '\($0)' can not be converted to the expected type (\(T.self))")
            }
            return result
        }
    }

    /// Return parameter with specified id as a certain type
    /// - Parameters:
    ///   - s: parameter id
    ///   - as: type we want returned
    @_disfavoredOverload
    public func requireAll<T: RawRepresentable>(_ s: String, as: T.Type) throws -> [T] where T.RawValue == String {
        try self[values: s[...]].map {
            guard let result = T(rawValue: String($0)) else {
                throw HTTPError(.badRequest, message: "One of the parameters '\($0)' can not be converted to the expected type (\(T.self))")
            }
            return result
        }
    }
}

/// Catch all support
extension Parameters {
    public static let recursiveCaptureKey: Substring = ":**:"

    ///  Return path elements caught by recursive capture
    public func getCatchAll() -> [Substring] {
        self[Self.recursiveCaptureKey].map { $0.split(separator: "/", omittingEmptySubsequences: true) } ?? []
    }

    /// Set path components caught by recursive capture
    /// - Parameters:
    ///   - value: parameter value
    public mutating func setCatchAll(_ value: Substring) {
        guard !self.has(Self.recursiveCaptureKey) else { return }
        self[Self.recursiveCaptureKey] = value
    }
}
