//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import ContainersPreview
public import NIOCore

extension ByteBuffer {
    /// Drains `buffer` into a newly allocated `ByteBuffer`.
    @usableFromInline
    package init<Buffer: RangeReplaceableContainer<UInt8> & ~Copyable>(
        draining buffer: inout Buffer
    ) where Buffer.Element: ~Copyable {
        self.init()
        self.reserveCapacity(buffer.count)

        var consumer = buffer.consumeAll()
        // `while !done { ... }` instead of `while true { ... break }` to dodge a SIL ownership-verifier crash on the
        // nightly main toolchain (https://github.com/swiftlang/swift/issues/89639).
        var done = false
        while !done {
            let span = consumer.drainNext()
            if span.isEmpty {
                done = true
            } else {
                self.writeBytes(span.span.bytes)
            }
        }
    }

    /// Drains `buffer` into a newly allocated `ByteBuffer`.
    @usableFromInline
    package mutating func writeBytes<Buffer: RangeReplaceableContainer<UInt8> & ~Copyable>(
        draining buffer: inout Buffer
    ) where Buffer.Element: ~Copyable {
        var consumer = buffer.consumeAll()
        // `while !done { ... }` instead of `while true { ... break }` to dodge a SIL ownership-verifier crash on the
        // nightly main toolchain (https://github.com/swiftlang/swift/issues/89639).
        var done = false
        while !done {
            let span = consumer.drainNext()
            if span.isEmpty {
                done = true
            } else {
                self.writeBytes(span.span.bytes)
            }
        }
    }
}
