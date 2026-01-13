//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

extension Sequence<UInt8> {
    /// return a hexEncoded string buffer from an array of bytes
    func hexDigest() -> String {
        self.map { String($0, radix: 16, padding: 2) }.joined(separator: "")
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
