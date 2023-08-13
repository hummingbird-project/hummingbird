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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

/*
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
         try await self.request.applicationContext.persist.driver.create(key: key, value: value, expires: expires, request: self.request)
     }

     /// Set value for key that will expire after a certain time
     /// - Parameters:
     ///   - key: key string
     ///   - value: value
     ///   - expires: time key/value pair will expire
     public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil) async throws {
         try await self.request.applicationContext.persist.driver.set(key: key, value: value, expires: expires, request: self.request)
     }

     /// Get value for key
     /// - Parameters:
     ///   - key: key string
     ///   - type: Type of value
     /// - Returns: Value
     public func get<Object: Codable>(key: String, as type: Object.Type) async throws -> Object? {
         return try await self.request.applicationContext.persist.driver.get(key: key, as: type, request: self.request)
     }

     /// Remove value for key
     /// - Parameter key: key string
     public func remove(key: String) async throws {
         try await self.request.applicationContext.persist.driver.remove(key: key, request: self.request)
     }
 }
 */
