//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics

/// Generate Unique ID for each request
public struct RequestID: CustomStringConvertible, Sendable {
    let low: UInt64

    public init() {
        self.low = Self.nextID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
    }

    public var description: String {
        Self.high + self.formatAsHexWithLeadingZeros(self.low)
    }

    func formatAsHexWithLeadingZeros(_ value: UInt64) -> String {
        let string = String(value, radix: 16)
        if string.count < 16 {
            return String(repeating: "0", count: 16 - string.count) + string
        } else {
            return string
        }
    }

    private static let high = String(UInt64.random(in: .min ... .max), radix: 16)
    private static let nextID = ManagedAtomic<UInt64>(UInt64.random(in: .min ... .max))
}
