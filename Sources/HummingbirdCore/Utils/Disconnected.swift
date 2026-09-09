//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// This is a helper type to move a non-Sendable value across isolation regions.
///
/// This will be eventually replaced when a version of it is added to the standard
/// library https://github.com/swiftlang/swift-evolution/blob/main/proposals/0538-disconnected.md
@usableFromInline
struct _Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
    // This is safe since we take the value as sending and take consumes it
    // and returns it as sending.
    private nonisolated(unsafe) var value: Value?

    @usableFromInline
    init(value: consuming sending Value) {
        unsafe self.value = .some(value)
    }

    @usableFromInline
    consuming func consume() -> sending Value {
        nonisolated(unsafe) let value = unsafe self.value.take()!
        return unsafe value
    }

    @usableFromInline
    mutating func exchange(newValue: consuming sending Value) -> sending Value {
        nonisolated(unsafe) let value = unsafe self.value.take()!
        unsafe self.value = consume newValue
        return unsafe value
    }
}
