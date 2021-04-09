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

/// In memory driver for persist system for storing persistent cross request key/value pairs
class HBMemoryPersistDriver: HBPersistDriver {
    init(eventLoopGroup: EventLoopGroup) {
        self.values = [:]
        self.eventLoop = eventLoopGroup.next()
        self.eventLoop.scheduleRepeatedTask(initialDelay: .hours(1), delay: .hours(1)) { _ in
            self._tidy()
        }
    }

    func set(key: String, value: String) {
        self.eventLoop.execute {
            self.values[key] = .init(value: value)
        }
    }

    func set(key: String, value: String, expires: TimeAmount) {
        self.eventLoop.execute {
            self.values[key] = .init(value: value, expires: expires)
        }
    }

    func get(key: String) -> EventLoopFuture<String?> {
        return self.eventLoop.submit {
            guard let item = self.values[key] else { return nil }
            guard let expires = item.epochExpires else { return item.value }
            guard Item.getEpochTime() <= expires else { return nil }
            return item.value
        }
    }

    func remove(key: String) {
        self.eventLoop.execute {
            self.values[key] = nil
        }
    }

    func tidy() {
        self.eventLoop.execute {
            self._tidy()
        }
    }

    private func _tidy() {
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
        let value: String
        /// epoch time for when item expires
        let epochExpires: Int?

        init(value: String, expires: TimeAmount) {
            self.value = value
            self.epochExpires = Self.getEpochTime() + Int(expires.nanoseconds / 1_000_000_000)
        }

        init(value: String) {
            self.value = value
            self.epochExpires = nil
        }

        static func getEpochTime() -> Int {
            var timeVal = timeval.init()
            gettimeofday(&timeVal, nil)
            return timeVal.tv_sec
        }
    }

    var values: [String: Item]
    let eventLoop: EventLoop
}
