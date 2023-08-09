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
public final class HBMemoryPersistDriver: HBPersistDriver {
    public init(eventLoopGroup: EventLoopGroup) {
        self.eventLoop = eventLoopGroup.next()
        self.values = [:]
        self.task = self.eventLoop.scheduleRepeatedTask(initialDelay: .hours(1), delay: .hours(1)) { _ in
            self.tidy()
        }
    }

    public func shutdown() {
        self.task?.cancel()
    }

    public func create<Object: Codable>(key: String, value: Object, expires: TimeAmount?, request: HBRequest) -> EventLoopFuture<Void> {
        return self.eventLoop.submit {
            guard self.values[key] == nil else { throw HBPersistError.duplicate }
            self.values[key] = .init(value: value, expires: expires)
        }
    }

    public func set<Object: Codable>(key: String, value: Object, expires: TimeAmount?, request: HBRequest) -> EventLoopFuture<Void> {
        return self.eventLoop.submit {
            self.values[key] = .init(value: value, expires: expires)
        }
    }

    public func get<Object: Codable>(key: String, as: Object.Type, request: HBRequest) -> EventLoopFuture<Object?> {
        return self.eventLoop.submit {
            guard let item = self.values[key] else { return nil }
            guard let expires = item.epochExpires else { return item.value as? Object }
            guard Item.getEpochTime() <= expires else { return nil }
            return item.value as? Object
        }
    }

    public func remove(key: String, request: HBRequest) -> EventLoopFuture<Void> {
        return self.eventLoop.submit {
            self.values[key] = nil
        }
    }

    private func tidy() {
        let currentTime = Item.getEpochTime()
        self.values = self.values.compactMapValues {
            if let expires = $0.epochExpires {
                if expires > currentTime {
                    return nil
                }
            }
            return $0
        }
    }

    struct Item {
        /// value stored
        let value: Codable
        /// epoch time for when item expires
        let epochExpires: Int?

        init(value: Codable, expires: TimeAmount?) {
            self.value = value
            self.epochExpires = expires.map { Self.getEpochTime() + Int($0.nanoseconds / 1_000_000_000) }
        }

        static func getEpochTime() -> Int {
            var timeVal = timeval.init()
            gettimeofday(&timeVal, nil)
            return timeVal.tv_sec
        }
    }

    let eventLoop: EventLoop
    var values: [String: Item]
    var task: RepeatedTask?
}

// We are able to conform HBMemoryPersistDriver to `@unchecked Sendable` as the value dictionary
// is only ever access on the one event loop and the task is only set in the `init`
extension HBMemoryPersistDriver: @unchecked Sendable {}
