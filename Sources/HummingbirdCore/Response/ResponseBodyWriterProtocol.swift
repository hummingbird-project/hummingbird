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

import HTTPTypes
import NIOCore

/// HTTP Response Body part writer
public protocol ResponseBodyWriterProtocol {
    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    mutating func write(_ buffer: ByteBuffer) async throws
    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws
    /// Finish writing body
    /// - Parameter trailingHeaders: Any trailing headers you want to include at end
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws
}

extension ResponseBodyWriterProtocol {
    /// Default implementation of writing a sequence of ByteBuffers
    @inlinable
    public mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for part in buffers {
            try await self.write(part)
        }
    }

    ///  Write AsyncSequence of ByteBuffers
    /// - Parameter buffers: ByteBuffer AsyncSequence
    @inlinable
    public mutating func write<BufferSequence: AsyncSequence>(_ buffers: BufferSequence) async throws where BufferSequence.Element == ByteBuffer {
        for try await buffer in buffers {
            try await self.write(buffer)
        }
    }
}
