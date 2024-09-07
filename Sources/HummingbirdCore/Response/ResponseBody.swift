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

import HTTPTypes
import NIOCore

/// Response body
public struct ResponseBody: Sendable {
    @usableFromInline
    let _write: @Sendable (inout any ResponseBodyWriter) async throws -> Void
    public let contentLength: Int?

    /// Initialise ResponseBody with closure writing body contents.
    ///
    /// When you have finished writing the response body you need to indicate you have
    /// finished by calling ``ResponseBodyWriter/finish(_:)``. At this
    /// point you can also send trailing headers by including them as a parameter in
    /// the finsh() call.
    /// ```
    /// let responseBody = ResponseBody(contentLength: contentLength) { writer in
    ///     try await writer.write(buffer)
    ///     try await writer.finish(nil)
    /// }
    /// ```
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    public init(contentLength: Int? = nil, _ write: @Sendable @escaping (inout any ResponseBodyWriter) async throws -> Void) {
        self._write = { writer in
            try await write(&writer)
        }
        self.contentLength = contentLength
    }

    /// Initialise empty ResponseBody
    public init() {
        self.init(contentLength: 0) { writer in
            try await writer.finish(nil)
        }
    }

    /// Initialise ResponseBody that contains a single ByteBuffer
    /// - Parameter byteBuffer: ByteBuffer to write
    public init(byteBuffer: ByteBuffer) {
        self.init(contentLength: byteBuffer.readableBytes) { writer in
            try await writer.write(byteBuffer)
            try await writer.finish(nil)
        }
    }

    /// Initialise ResponseBody that contains a sequence of ByteBuffers
    /// - Parameter byteBuffers: Sequence of ByteBuffers to write
    public init<BufferSequence: Sequence & Sendable>(contentsOf byteBuffers: BufferSequence) where BufferSequence.Element == ByteBuffer {
        self.init(contentLength: byteBuffers.map(\.readableBytes).reduce(0, +)) { writer in
            try await writer.write(contentsOf: byteBuffers)
            try await writer.finish(nil)
        }
    }

    /// Initialise ResponseBody with an AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: ByteBuffer AsyncSequence
    public init<BufferSequence: AsyncSequence & Sendable>(asyncSequence: BufferSequence) where BufferSequence.Element == ByteBuffer {
        self.init { writer in
            try await writer.write(asyncSequence)
            try await writer.finish(nil)
        }
    }

    @inlinable
    public consuming func write(_ writer: consuming any ResponseBodyWriter) async throws {
        try await self._write(&writer)
    }

    /// Returns a ResponseBody containing the results of mapping the given closure over the sequence of
    /// ByteBuffers written.
    /// - Parameter transform: A mapping closure applied to every ByteBuffer in ResponseBody
    /// - Returns: The transformed ResponseBody
    public consuming func map(_ transform: @escaping @Sendable (ByteBuffer) async throws -> ByteBuffer) -> ResponseBody {
        let body = self
        return Self.init { writer in
            try await body.write(writer.map(transform))
        }
    }

    /// Create new response body that calls a closure once original response body has been written
    /// to the channel
    ///
    /// When you return a response from a handler, this cannot be considered to be the point the
    /// response was written. This functions provides you a method for catching the point when the
    /// response has been fully written. If you drop the response in a middleware run after this
    /// point the post write closure will not get run.
    package func withPostWriteClosure(_ postWrite: @escaping @Sendable () async -> Void) -> Self {
        return .init(contentLength: self.contentLength) { writer in
            do {
                try await self.write(writer)
                await postWrite()
            } catch {
                await postWrite()
                throw error
            }
            return
        }
    }
}
