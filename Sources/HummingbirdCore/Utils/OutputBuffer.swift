//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

struct OutputBuffer<T>: ~Copyable  // ~Escapable
{
    let start: UnsafeMutablePointer<T>
    let capacity: Int
    var initialized: Int = 0

    deinit {
        // `self` always borrows memory, and it shouldn't have gotten here.
        // Failing to use `relinquishBorrowedMemory()` is an error.
        if initialized > 0 {
            fatalError()
        }
    }

    // precondition: pointer points to uninitialized memory for count elements
    init(initializing: UnsafeMutablePointer<T>, capacity: Int) {
        start = initializing
        self.capacity = capacity
    }
}

extension OutputBuffer {
    mutating func appendElement(_ value: T) {
        precondition(initialized < capacity, "Output buffer overflow")
        start.advanced(by: initialized).initialize(to: value)
        initialized &+= 1
    }
}

extension OutputBuffer {
    consuming func relinquishBorrowedMemory() -> UnsafeMutableBufferPointer<T> {
        let start = self.start
        let initialized = self.initialized
        discard self
        return .init(start: start, count: initialized)
    }
}
