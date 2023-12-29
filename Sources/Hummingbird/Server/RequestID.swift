//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
struct RequestID: CustomStringConvertible {
    let low: UInt64
    let high: UInt64

    init() {
        self.low = Self.globalRequestID.loadThenWrappingIncrement(by: 1, ordering: .relaxed)
        self.high = Self.instanceIdentifier
    }

    var description: String {
        self.formatAsHexWithLeadingZeros(self.high) + self.formatAsHexWithLeadingZeros(self.low)
    }

    func formatAsHexWithLeadingZeros(_ value: UInt64) -> String {
        let string = String(value, radix: 16)
        if string.count < 16 {
            return String(repeating: "0", count: 16 - string.count) + string
        } else {
            return string
        }
    }

    private static let instanceIdentifier = UInt64.random(in: .min ... .max)
    private static let globalRequestID = ManagedAtomic<UInt64>(UInt64.random(in: .min ... .max))
}
