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

import NIOCore

/// HTTP Response Body part writer
public protocol ResponseBodyWriter {
    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    func write(_ buffer: ByteBuffer) async throws
    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws
}

extension ResponseBodyWriter {
    /// Default implementation of writing a sequence of ByteBuffers
    @inlinable
    public func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for part in buffers {
            try await self.write(part)
        }
    }
}

struct MappedResponseBodyWriter<ParentWriter: ResponseBodyWriter>: ResponseBodyWriter {
    fileprivate let parentWriter: ParentWriter
    fileprivate let transform: @Sendable (ByteBuffer) async throws -> ByteBuffer

    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    func write(_ buffer: ByteBuffer) async throws {
        try await self.parentWriter.write(self.transform(buffer))
    }

    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for part in buffers {
            try await self.parentWriter.write(self.transform(part))
        }
    }
}

extension ResponseBodyWriter {
    /// Return ResponseBodyWriter that applies transform to all ByteBuffers written to it
    /// ResponseBodyWriter.
    public consuming func map(_ transform: @escaping @Sendable (ByteBuffer) async throws -> ByteBuffer) -> some ResponseBodyWriter {
        MappedResponseBodyWriter(parentWriter: self, transform: transform)
    }
}
