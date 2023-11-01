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

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import NIOCore

/// In memory driver for persist system for storing persistent cross request key/value pairs
public actor HBMemoryPersistDriver<C: Clock>: HBPersistDriver where C.Duration == Duration {
    public init(_ clock: C = .suspending) {
        self.values = [:]
        self.clock = clock
    }

    public func create<Object: Codable>(key: String, value: Object, expires: Duration?) async throws {
        guard self.values[key] == nil else { throw HBPersistError.duplicate }
        self.values[key] = .init(value: value, expires: expires.map { self.clock.now.advanced(by: $0) })
    }

    public func set<Object: Codable>(key: String, value: Object, expires: Duration?) async throws {
        self.values[key] = .init(value: value, expires: expires.map { self.clock.now.advanced(by: $0) })
    }

    public func get<Object: Codable>(key: String, as: Object.Type) async throws -> Object? {
        guard let item = self.values[key] else { return nil }
        guard let expires = item.expires else { return item.value as? Object }
        guard self.clock.now <= expires else { return nil }
        return item.value as? Object
    }

    public func remove(key: String) async throws {
        self.values[key] = nil
    }

    private func tidy() {
        /*        let currentTime = Item.getEpochTime()
         self.values = self.values.compactMapValues {
             if let expires = $0.epochExpires {
                 if expires > currentTime {
                     return nil
                 }
             }
             return $0
         }*/
    }

    struct Item {
        /// value stored
        let value: Codable
        /// epoch time for when item expires
        let expires: C.Instant?

        init(value: Codable, expires: C.Instant?) {
            self.value = value
            self.expires = expires
        }
    }

    var values: [String: Item]
    let clock: C
}
