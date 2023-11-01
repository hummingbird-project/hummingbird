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

import NIOCore
import ServiceLifecycle

/// Protocol for driver supporting persistent Key/Value pairs across requests
public protocol HBPersistDriver: Service {
    /// shutdown driver
    func shutdown() async throws

    /// create key/value pair. If key already exist throw `HBPersistError.duplicate` error
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    func create<Object: Codable>(key: String, value: Object, expires: Duration?) async throws

    /// set value for key. If value already exists overwrite it
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    func set<Object: Codable>(key: String, value: Object, expires: Duration?) async throws

    /// get value for key
    /// - Parameters:
    ///   - key: Key used to look for value
    ///   - as: Type you want value to be returned as. If it cannot be returned as this value then nil will be returned
    func get<Object: Codable>(key: String, as: Object.Type) async throws -> Object?

    /// remove value associated with key
    /// - Parameters:
    ///   - key: Key used to look for value
    func remove(key: String) async throws
}

extension HBPersistDriver {
    /// default implemenation of shutdown()
    public func shutdown() async throws {}

    /// create key/value pair. If key already exist throw `HBPersistError.duplicate` error
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    public func create<Object: Codable>(key: String, value: Object) async throws {
        try await self.create(key: key, value: value, expires: nil)
    }

    /// set value for key. If value already exists overwrite it
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    public func set<Object: Codable>(key: String, value: Object) async throws {
        try await self.set(key: key, value: value, expires: nil)
    }

    public func run() async throws {
        await ShutdownWaiter().wait()
        try await self.shutdown()
    }
}
