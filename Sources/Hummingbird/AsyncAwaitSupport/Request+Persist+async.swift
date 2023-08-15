//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension HBPersistDriver {
    /// create key/value pair. If key already exist throw `HBPersistError.duplicate` error
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    ///   - request: Request making this call
    public func create<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil, request: HBRequest) async throws {
        try await self.create(key: key, value: value, expires: expires, request: request).get()
    }

    /// set value for key. If value already exists overwrite it
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    ///   - request: Request making this call
    public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil, request: HBRequest) async throws {
        try await self.set(key: key, value: value, expires: expires, request: request).get()
    }

    /// get value for key
    /// - Parameters:
    ///   - key: Key used to look for value
    ///   - as: Type you want value to be returned as. If it cannot be returned as this value then nil will be returned
    ///   - request: Request making this call
    public func get<Object: Codable>(key: String, as type: Object.Type, request: HBRequest) async throws -> Object? {
        try await self.get(key: key, as: type, request: request).get()
    }

    /// remove value associated with key
    /// - Parameters:
    ///   - key: Key used to look for value
    ///   - request: Request making this call
    public func remove(key: String, request: HBRequest) async throws {
        try await self.remove(key: key, request: request).get()
    }
}
