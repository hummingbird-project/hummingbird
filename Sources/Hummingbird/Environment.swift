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

#if compiler(>=5.6)
#if os(Linux)
@preconcurrency import Glibc
#else
@preconcurrency import Darwin.C
#endif
#else
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
#endif

/// Access environment variables
public struct HBEnvironment: Decodable, ExpressibleByDictionaryLiteral {
    // shared environment
    public static let shared: HBEnvironment = .init()

    /// initialize from environment variables
    public init() {
        self.values = Self.getEnvironment()
    }

    /// initialize from dictionary
    public init(values: [String: String]) {
        self.values = Self.getEnvironment()
        for (key, value) in values {
            self.values[key.lowercased()] = value
        }
    }

    /// initialize from dictionary literal
    public init(dictionaryLiteral elements: (String, String)...) {
        self.values = Self.getEnvironment()
        for element in elements {
            self.values[element.0.lowercased()] = element.1
        }
    }

    /// Initialize from Decodable
    public init(from decoder: Decoder) throws {
        self.values = Self.getEnvironment()
        let container = try decoder.singleValueContainer()
        let decodedValues = try container.decode([String: String].self)
        for (key, value) in decodedValues {
            self.values[key.lowercased()] = value
        }
    }

    /// Get environment variable with name
    /// - Parameter s: Environment variable name
    public func get(_ s: String) -> String? {
        return self.values[s.lowercased()]
    }

    /// Get environment variable with name as a certain type
    /// - Parameters:
    ///   - s: Environment variable name
    ///   - as: Type we want variable to be cast to
    public func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        return self.values[s.lowercased()].map { T(String($0)) } ?? nil
    }

    /// Set environment variable
    /// - Parameters:
    ///   - s: Environment variable name
    ///   - value: Environment variable name value
    public mutating func set(_ s: String, value: String?) {
        self.values[s.lowercased()] = value
    }

    /// Construct environment variable map
    static func getEnvironment() -> [String: String] {
        var values: [String: String] = [:]
        let equalSign = Character("=")
        let envp = environ
        var idx = 0

        while let entry = envp.advanced(by: idx).pointee {
            let entry = String(cString: entry)
            if let i = entry.firstIndex(of: equalSign) {
                let key = String(entry.prefix(upTo: i))
                let value = String(entry.suffix(from: i).dropFirst())
                values[key.lowercased()] = value
            }
            idx += 1
        }
        return values
    }

    var values: [String: String]
}

extension HBEnvironment: CustomStringConvertible {
    public var description: String {
        String(describing: self.values)
    }
}
