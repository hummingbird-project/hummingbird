//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension Sequence<UInt8> {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        return self.map { String($0, radix: 16, padding: 2) }.joined(separator: "")
    }
}

extension String {
    /// Creates a `String` from a given `Int` with a given base (`radix`), padded with
    /// zeroes to the provided `padding` size.
    ///
    /// - parameters:
    ///     - radix: radix base to use for conversion.
    ///     - padding: the desired lenght of the resulting string.
    @inlinable
    internal init(_ value: some BinaryInteger, radix: Int, padding: Int) {
        let formatted = String(value, radix: radix)
        self = String(repeating: "0", count: padding - formatted.count) + formatted
    }
}
