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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension HBRequest.Persist {
    /// Set value for key that will expire after a certain time.
    ///
    /// Doesn't check to see if key already exists. Some drivers may fail it key already exists
    /// - Parameters:
    ///   - key: key string
    ///   - value: value
    ///   - expires: time key/value pair will expire
    public func create<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil) async throws {
        try await self.request.application.persist.driver.create(key: key, value: value, expires: expires, request: self.request).get()
    }

    /// Set value for key that will expire after a certain time
    /// - Parameters:
    ///   - key: key string
    ///   - value: value
    ///   - expires: time key/value pair will expire
    public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil) async throws {
        try await self.request.application.persist.driver.set(key: key, value: value, expires: expires, request: self.request).get()
    }

    /// Get value for key
    /// - Parameters:
    ///   - key: key string
    ///   - type: Type of value
    /// - Returns: Value
    public func get<Object: Codable>(key: String, as type: Object.Type) async throws -> Object? {
        return try await self.request.application.persist.driver.get(key: key, as: type, request: self.request).get()
    }

    /// Remove value for key
    /// - Parameter key: key string
    public func remove(key: String) async throws {
        try await self.request.application.persist.driver.remove(key: key, request: self.request).get()
    }
}
