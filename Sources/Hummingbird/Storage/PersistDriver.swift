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

/// Protocol for driver supporting persistent Key/Value pairs across requests
public protocol HBPersistDriver {
    /// shutdown driver
    func shutdown()
    /// create key/value pair. If key already exist throw `HBPersistError.duplicate` error
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    ///   - request: Request making this call
    func create<Object: Codable>(key: String, value: Object, expires: TimeAmount?, request: HBRequest) -> EventLoopFuture<Void>

    /// set value for key. If value already exists overwrite it
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    ///   - request: Request making this call
    func set<Object: Codable>(key: String, value: Object, expires: TimeAmount?, request: HBRequest) -> EventLoopFuture<Void>

    /// get value for key
    /// - Parameters:
    ///   - key: Key used to look for value
    ///   - as: Type you want value to be returned as. If it cannot be returned as this value then nil will be returned
    ///   - request: Request making this call
    func get<Object: Codable>(key: String, as: Object.Type, request: HBRequest) -> EventLoopFuture<Object?>

    /// remove value associated with key
    /// - Parameters:
    ///   - key: Key used to look for value
    ///   - request: Request making this call
    func remove(key: String, request: HBRequest) -> EventLoopFuture<Void>
}

extension HBPersistDriver {
    /// default implemenation of shutdown()
    public func shutdown() {}
    /// create key/value pair. If key already exist throw `HBPersistError.duplicate` error
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - request: Request making this call
    func create<Object: Codable>(key: String, value: Object, request: HBRequest) -> EventLoopFuture<Void> {
        self.create(key: key, value: value, expires: nil, request: request)
    }

    /// set value for key. If value already exists overwrite it
    /// - Parameters:
    ///   - key: Key to store value against
    ///   - value: Codable value to store
    ///   - expires: If non-nil defines time that value will expire
    ///   - request: Request making this call
    func set<Object: Codable>(key: String, value: Object, request: HBRequest) -> EventLoopFuture<Void> {
        self.set(key: key, value: value, expires: nil, request: request)
    }
}

/// Factory class for persist drivers
public struct HBPersistDriverFactory {
    public let create: (HBApplication) -> HBPersistDriver

    /// Initialize HBPersistDriverFactory
    /// - Parameter create: HBPersistDriver factory function
    public init(create: @escaping (HBApplication) -> HBPersistDriver) {
        self.create = create
    }

    /// In memory driver for persist system
    public static var memory: HBPersistDriverFactory {
        .init(create: { app in HBMemoryPersistDriver(eventLoopGroup: app.eventLoopGroup) })
    }
}
