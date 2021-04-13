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

/// In memory driver for persist system for storing persistent cross request key/value pairs
class HBMemoryPersistDriver: HBPersistDriver {
    init(eventLoopGroup: EventLoopGroup) {
        self.values = [:]
        self.task = eventLoopGroup.next().scheduleRepeatedTask(initialDelay: .hours(1), delay: .hours(1)) { _ in
            self.tidy()
        }
    }

    func shutdown() {
        self.task?.cancel()
    }

    func create<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil, request: HBRequest) -> EventLoopFuture<Void> {
        return request.eventLoop.submit {
            self.values[key] = .init(value: value, expires: expires)
        }
    }

    func set<Object: Codable>(key: String, value: Object, expires: TimeAmount? = nil, request: HBRequest) -> EventLoopFuture<Void> {
        return request.eventLoop.submit {
            self.values[key] = .init(value: value, expires: expires)
        }
    }

    func get<Object: Codable>(key: String, as: Object.Type, request: HBRequest) -> EventLoopFuture<Object?> {
        return request.eventLoop.submit {
            guard let item = self.values[key] else { return nil }
            guard let expires = item.epochExpires else { return item.value as? Object }
            guard Item.getEpochTime() <= expires else { return nil }
            return item.value as? Object
        }
    }

    func remove(key: String, request: HBRequest) -> EventLoopFuture<Void> {
        return request.eventLoop.submit {
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

    var values: [String: Item]
    var task: RepeatedTask?
}
