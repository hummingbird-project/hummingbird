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

/// Response body writer with transform applied to each element written
@usableFromInline
struct MappedResponseBodyWriter<ParentWriter: ResponseBodyWriterProtocol>: ResponseBodyWriterProtocol {
    var parentWriter: ParentWriter
    var transform: @Sendable (ByteBuffer) async throws -> ByteBuffer

    @usableFromInline
    init(parentWriter: ParentWriter, transform: @escaping @Sendable (ByteBuffer) async throws -> ByteBuffer) {
        self.parentWriter = parentWriter
        self.transform = transform
    }

    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    @usableFromInline
    mutating func write(_ buffer: ByteBuffer) async throws {
        try await self.parentWriter.write(self.transform(buffer))
    }

    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    @usableFromInline
    mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        for part in buffers {
            try await self.parentWriter.write(self.transform(part))
        }
    }

    /// Finish writing body
    /// - Parameter trailingHeaders: Any trailing headers you want to include at end
    @usableFromInline
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws {
        try await self.parentWriter.finish(trailingHeaders)
    }
}

extension ResponseBodyWriter {
    /// Return ResponseBodyWriter that applies transform to all ByteBuffers written to it
    /// ResponseBodyWriter.
    @inlinable
    public consuming func map(_ transform: @escaping @Sendable (ByteBuffer) async throws -> ByteBuffer) -> ResponseBodyWriter {
        self.wrapped._map(transform)
    }
}

extension ResponseBodyWriterProtocol {
    /// Return ResponseBodyWriter that applies transform to all ByteBuffers written to it
    /// ResponseBodyWriter.
    ///
    /// Used internally to ensure we aren't passing an existential writer around that references another existential writer
    @usableFromInline
    consuming func _map(_ transform: @escaping @Sendable (ByteBuffer) async throws -> ByteBuffer) -> ResponseBodyWriter {
        .init(MappedResponseBodyWriter(parentWriter: self, transform: transform))
    }
}
