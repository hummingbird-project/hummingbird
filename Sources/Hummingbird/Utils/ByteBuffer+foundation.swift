//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension ByteBuffer {
    /// Controls how bytes are transferred between `ByteBuffer` and other storage types.
    @usableFromInline
    package enum _ByteTransferStrategy: Sendable {
        /// Force a copy of the bytes.
        case copy

        /// Do not copy the bytes if at all possible.
        case noCopy

        /// Use a heuristic to decide whether to copy the bytes or not.
        case automatic
    }

    // MARK: - Data APIs

    /// Return `length` bytes starting at `index` and return the result as `Data`. This will not change the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// `ByteBuffer` will use a heuristic to decide whether to copy the bytes or whether to reference `ByteBuffer`'s
    /// underlying storage from the returned `Data` value. If you want manual control over the byte transferring
    /// behaviour, please use `getData(at:byteTransferStrategy:)`.
    ///
    /// - parameters:
    ///     - index: The starting index of the bytes of interest into the `ByteBuffer`
    ///     - length: The number of bytes of interest
    /// - returns: A `Data` value containing the bytes of interest or `nil` if the selected bytes are not readable.
    @usableFromInline
    package func _getData(at index: Int, length: Int) -> Data? {
        self.getData(at: index, length: length, byteTransferStrategy: .automatic)
    }

    /// Return `length` bytes starting at `index` and return the result as `Data`. This will not change the reader index.
    /// The selected bytes must be readable or else `nil` will be returned.
    ///
    /// - parameters:
    ///     - index: The starting index of the bytes of interest into the `ByteBuffer`
    ///     - length: The number of bytes of interest
    ///     - byteTransferStrategy: Controls how to transfer the bytes. See `ByteTransferStrategy` for an explanation
    ///                             of the options.
    /// - returns: A `Data` value containing the bytes of interest or `nil` if the selected bytes are not readable.
    @usableFromInline
    package func _getData(at index0: Int, length: Int, byteTransferStrategy: _ByteTransferStrategy) -> Data? {
        let index = index0 - self.readerIndex
        guard index >= 0 && length >= 0 && index <= self.readableBytes - length else {
            return nil
        }
        let doCopy: Bool
        switch byteTransferStrategy {
        case .copy:
            doCopy = true
        case .noCopy:
            doCopy = false
        case .automatic:
            doCopy = length <= 256 * 1024
        }

        return self.withUnsafeReadableBytesWithStorageManagement { ptr, storageRef in
            if doCopy {
                return Data(
                    bytes: UnsafeMutableRawPointer(mutating: ptr.baseAddress!.advanced(by: index)),
                    count: Int(length)
                )
            } else {
                _ = storageRef.retain()
                return Data(
                    bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr.baseAddress!.advanced(by: index)),
                    count: Int(length),
                    deallocator: .custom { _, _ in storageRef.release() }
                )
            }
        }
    }
}
