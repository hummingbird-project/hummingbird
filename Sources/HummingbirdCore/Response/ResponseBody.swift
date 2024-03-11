//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
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

public protocol ResponseBodyWriter {
    func write(_ buffer: ByteBuffer) async throws
}

/// Response body
public struct ResponseBody: Sendable {
    public let write: @Sendable (any ResponseBodyWriter) async throws -> HTTPFields?
    public let contentLength: Int?

    /// Initialise ResponseBody with closure writing body contents
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    public init(contentLength: Int? = nil, _ write: @Sendable @escaping (any ResponseBodyWriter) async throws -> Void) {
        self.write = { try await write($0); return nil }
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

    /// Initialise ResponseBody with closure writing body contents
    ///
    /// This version of init is private and only available via ``withTrailingHeaders`` because
    /// if it is public the compiler gets confused when a complex closure is provided.
    private init(contentLength: Int? = nil, write: @Sendable @escaping (any ResponseBodyWriter) async throws -> HTTPFields?) {
        self.write = { return try await write($0) }
        self.contentLength = contentLength
    }
}
