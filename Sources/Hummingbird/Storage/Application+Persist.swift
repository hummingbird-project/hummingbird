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
    public struct Persist {
        let driver: HBPersistDriver

        public init(_ factory: HBPersistDriverFactory, application: HBApplication) {
            self.driver = factory.create(application)
        }

        public func set<Object: Codable>(key: String, value: Object) {
            self.driver.set(key: key, value: value)
        }

        public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount) {
            self.driver.set(key: key, value: value, expires: expires)
        }

        public func get<Object: Codable>(key: String, as type: Object.Type) -> EventLoopFuture<Object?> {
            return self.driver.get(key: key, as: type)
        }

        public func remove(key: String) {
            self.driver.remove(key: key)
        }
    }

    public var persist: Persist { self.extensions.get(\.persist) }

    public func addPersist(using: HBPersistDriverFactory) {
        self.extensions.set(\.persist, value: .init(using, application: self))
    }
}

extension HBRequest {
    public var persist: HBApplication.Persist { self.application.persist }
}
