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

import HummingbirdCore
import NIOCore
import NIOFileSystem

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin.C
#elseif canImport(Android)
import Android
#else
#error("Unsupported platform")
#endif

/// Access environment variables
public struct Environment: Sendable, Decodable, ExpressibleByDictionaryLiteral {
    public struct Error: Swift.Error, Equatable {
        enum Code {
            case dotEnvParseError
            case variableDoesNotExist
            case variableDoesNotConvert
        }

        fileprivate let code: Code
        public let message: String?
        fileprivate init(_ code: Code, message: String? = nil) {
            self.code = code
            self.message = message
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.code == rhs.code
        }

        /// Required variable does not exist
        public static var variableDoesNotExist: Self { .init(.variableDoesNotExist) }
        /// Required variable does not convert to type
        public static var variableDoesNotConvert: Self { .init(.variableDoesNotConvert) }
        /// Error while parsing dot env file
        public static var dotEnvParseError: Self { .init(.dotEnvParseError) }
    }

    var values: [String: String]

    /// Initialize from environment variables
    public init() {
        self.values = Self.getEnvironment()
    }

    /// Initialize from dictionary
    public init(values: [String: String]) {
        self.values = Self.getEnvironment()
        for (key, value) in values {
            self.values[key.lowercased()] = value
        }
    }

    /// Initialize from dictionary literal
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
        self.values[s.lowercased()]
    }

    /// Get environment variable with name as a certain type
    /// - Parameters:
    ///   - s: Environment variable name
    ///   - as: Type we want variable to be cast to
    public func get<T: LosslessStringConvertible>(_ s: String, as: T.Type) -> T? {
        self.values[s.lowercased()].map { T(String($0)) } ?? nil
    }

    /// Require environment variable with name
    /// - Parameter s: Environment variable name
    public func require(_ s: String) throws -> String {
        guard let value = self.values[s.lowercased()] else {
            throw Error(.variableDoesNotExist, message: "Environment variable '\(s)' does not exist")
        }
        return value
    }

    /// Require environment variable with name as a certain type
    /// - Parameters:
    ///   - s: Environment variable name
    ///   - as: Type we want variable to be cast to
    public func require<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> T {
        let stringValue = try self.require(s)
        guard let value = T(stringValue) else {
            throw Error(.variableDoesNotConvert, message: "Environment variable '\(s)' can not be converted to \(T.self)")
        }
        return value
    }

    /// Set environment variable
    ///
    /// This sets the variable within this type and also calls `setenv` so future versions
    /// of this type will also have this variable set.
    /// - Parameters:
    ///   - s: Environment variable name
    ///   - value: Environment variable name value
    public mutating func set(_ s: String, value: String?) {
        self.values[s.lowercased()] = value
        if let value {
            setenv(s, value, 1)
        } else {
            unsetenv(s)
        }
    }

    /// Merge two environment variable sets together and return result
    ///
    /// If an environment variable exists in both sets it will choose the version from the second
    /// set of environment variables
    /// - Parameter env: environemnt variables to merge into this environment variable set
    public func merging(with env: Environment) -> Environment {
        .init(rawValues: self.values.merging(env.values) { $1 })
    }

    /// Construct environment variable map
    static func getEnvironment() -> [String: String] {
        var values: [String: String] = [:]
        for item in ProcessInfo.processInfo.environment {
            values[item.key.lowercased()] = item.value
        }
        return values
    }

    /// Create Environment initialised from the `.env` file
    public static func dotEnv(_ dotEnvPath: String = ".env") async throws -> Self {
        guard let dotEnv = await loadDotEnv(dotEnvPath) else { return [:] }
        return try .init(rawValues: self.parseDotEnv(dotEnv))
    }

    /// Load `.env` file into string
    internal static func loadDotEnv(_ dotEnvPath: String = ".env") async -> String? {
        do {
            return try await FileSystem.shared.withFileHandle(forReadingAt: .init(dotEnvPath)) { fileHandle in
                let buffer = try await fileHandle.readToEnd(maximumSizeAllowed: .unlimited)
                return String(buffer: buffer)
            }
        } catch {
            return nil
        }
    }

    /// Parse a `.env` file
    internal static func parseDotEnv(_ dotEnv: String) throws -> [String: String] {
        enum DotEnvParserState {
            case readingKey
            case skippingEquals(key: String)
            case readingValue(key: String)
        }
        var dotEnvDictionary: [String: String] = [:]
        var parser = Parser(dotEnv)
        var state: DotEnvParserState = .readingKey
        do {
            while !parser.reachedEnd() {
                parser.read(while: \.isWhitespace)

                switch state {
                case .readingKey:
                    // handle empty lines at the end
                    guard !parser.reachedEnd() else { break }

                    // check for comment
                    let c = parser.current()
                    if c == "#" {
                        do {
                            _ = try parser.read(until: \.isNewline)
                            parser.unsafeAdvance()
                        } catch Parser.Error.overflow {
                            parser.moveToEnd()
                            break
                        }
                        continue
                    }
                    let key = try parser.read(until: { $0.isWhitespace || $0 == "=" }).string
                    state = .skippingEquals(key: key)

                case .skippingEquals(let key):
                    let c = try parser.character()
                    // we are expecting an equals
                    guard c == "=" else { throw Error.dotEnvParseError }
                    state = .readingValue(key: key)

                case .readingValue(let key):
                    let value: String
                    if try parser.read("\"") {
                        value = try parser.read(until: { $0 == "\"" }).string
                        parser.unsafeAdvance()
                    } else {
                        value = try parser.read(until: \.isWhitespace, throwOnOverflow: false).string
                    }
                    dotEnvDictionary[key.lowercased()] = value
                    state = .readingKey
                }
            }
            guard case .readingKey = state else { throw Error.dotEnvParseError }
        } catch {
            throw Error.dotEnvParseError
        }
        return dotEnvDictionary
    }

    /// initialize from an already processed dictionary
    private init(rawValues: [String: String]) {
        self.values = rawValues
    }
}

extension Environment: CustomStringConvertible {
    public var description: String {
        String(describing: self.values)
    }
}
