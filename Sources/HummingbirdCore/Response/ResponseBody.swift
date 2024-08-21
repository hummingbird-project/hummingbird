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
    let _write: @Sendable (any ResponseBodyWriter) async throws -> Void
    public let contentLength: Int?

    /// Initialise ResponseBody with closure writing body contents
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    public init(contentLength: Int? = nil, _ write: @Sendable @escaping (any ResponseBodyWriter) async throws -> Void) {
        self._write = { writer in
            try await write(writer)
            try await writer.finish(nil)
        }
        self.contentLength = contentLength
    }

    /// Initialise empty ResponseBody
    public init() {
        self.init(contentLength: 0) { _ in }
    }

    /// Initialise ResponseBody that contains a single ByteBuffer
    /// - Parameter byteBuffer: ByteBuffer to write
    public init(byteBuffer: ByteBuffer) {
        self.init(contentLength: byteBuffer.readableBytes) { writer in
            try await writer.write(byteBuffer)
        }
    }

    /// Initialise ResponseBody with an AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: ByteBuffer AsyncSequence
    public init<BufferSequence: AsyncSequence & Sendable>(asyncSequence: BufferSequence) where BufferSequence.Element == ByteBuffer {
        self.init { writer in
            for try await buffer in asyncSequence {
                try await writer.write(buffer)
            }
            return
        }
    }

    /// Create ResponseBody that returns trailing headers from its closure once all the
    /// body parts have been written
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    ///         trailing headers are returned from the closure after all the body parts have been
    ///         written
    public static func withTrailingHeaders(
        contentLength: Int? = nil,
        _ write: @Sendable @escaping (any ResponseBodyWriter) async throws -> HTTPFields?
    ) -> Self {
        self.init(contentLength: contentLength, write: write)
    }

    @inlinable
    public consuming func write(_ writer: any ResponseBodyWriter) async throws {
        try await self._write(writer)
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

    /// Create new response body that call a callback once original response body has been written
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

    /// Initialise ResponseBody with closure writing body contents
    ///
    /// This version of init is private and only available via ``withTrailingHeaders`` because
    /// if it is public the compiler gets confused when a complex closure is provided.
    private init(contentLength: Int? = nil, write: @Sendable @escaping (any ResponseBodyWriter) async throws -> HTTPFields?) {
        self._write = {
            let trailingHeaders = try await write($0)
            try await $0.finish(trailingHeaders)
        }
        self.contentLength = contentLength
    }
}
