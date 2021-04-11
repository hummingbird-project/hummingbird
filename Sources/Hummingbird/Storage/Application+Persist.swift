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

extension HBApplication {
    /// Framework for storing persistent key/value pairs between mulitple requests
    public struct Persist {
        let driver: HBPersistDriver

        /// Initialise Persist struct
        /// - Parameters
        ///   - factory: Persist driver factory
        ///   - application: reference to application that can be used during persist driver creation
        public init(_ factory: HBPersistDriverFactory, application: HBApplication) {
            self.driver = factory.create(application)
        }

        /// Set value for key
        /// - Parameters:
        ///   - key: key string
        ///   - value: value
        /// - Returns: EventLoopFuture for when value has been set
        public func set<Object: Codable>(key: String, value: Object, request: HBRequest) -> EventLoopFuture<Void> {
            return self.driver.set(key: key, value: value, request: request)
        }

        /// Set value for key that will expire after a certain time
        /// - Parameters:
        ///   - key: key string
        ///   - value: value
        /// - Returns: EventLoopFuture for when value has been set
        public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount, request: HBRequest) -> EventLoopFuture<Void> {
            return self.driver.set(key: key, value: value, expires: expires, request: request)
        }

        /// Get value for key
        /// - Parameters:
        ///   - key: key string
        ///   - type: Type of value
        /// - Returns: EventLoopFuture that will be filled with value
        public func get<Object: Codable>(key: String, as type: Object.Type, request: HBRequest) -> EventLoopFuture<Object?> {
            return self.driver.get(key: key, as: type, request: request)
        }

        /// Remove value for key
        /// - Parameter key: key string
        public func remove(key: String, request: HBRequest) -> EventLoopFuture<Void> {
            return self.driver.remove(key: key, request: request)
        }
    }

    /// Accessor for persist framework
    public var persist: Persist { self.extensions.get(\.persist) }

    /// Add persist framework to `HBApplication`.
    /// - Parameter using: Factory struct that will create the persist driver when required
    public func addPersist(using: HBPersistDriverFactory) {
        self.extensions.set(\.persist, value: .init(using, application: self))
    }
}

extension HBRequest {
    /// Accessor for persist framework
    public var persist: HBApplication.Persist { self.application.persist }
}
