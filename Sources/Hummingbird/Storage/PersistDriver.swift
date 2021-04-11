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

import NIO

/// Protocol for driver supporting persistent Key/Value pairs across requests
public protocol HBPersistDriver {
    /// set value for key
    func set<Object: Codable>(key: String, value: Object) -> EventLoopFuture<Void>
    /// set value for key with how before the value expires
    func set<Object: Codable>(key: String, value: Object, expires: TimeAmount) -> EventLoopFuture<Void>
    /// get value for key
    func get<Object: Codable>(key: String, as: Object.Type) -> EventLoopFuture<Object?>
    /// remove value for key
    func remove(key: String) -> EventLoopFuture<Void>
}

/// Factory class for persist drivers
public struct HBPersistDriverFactory {
    public let create: (HBApplication) -> HBPersistDriver

    /// In memory driver for persist system
    public static var memory: HBPersistDriverFactory {
        .init(create: { app in HBMemoryPersistDriver(eventLoopGroup: app.eventLoopGroup) })
    }
}
