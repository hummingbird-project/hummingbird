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

import NIOCore

public protocol HBResponseBodyWriter {
    func write(_ buffer: ByteBuffer) async throws
}

/// Response body
public struct HBResponseBody: Sendable {
    let write: @Sendable (any HBResponseBodyWriter) async throws -> Void
    let contentLength: Int?

    /// Initialise HBResponseBody with closure writing body contents
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    public init(contentLength: Int? = nil, _ write: @Sendable @escaping (any HBResponseBodyWriter) async throws -> Void) {
        self.write = write
        self.contentLength = contentLength
    }

    /// Initialise empty HBResponseBody
    public init() {
        self.init(contentLength: 0) { _ in }
    }

    /// Initialise HBResponseBody that contains a single ByteBuffer
    /// - Parameter byteBuffer: ByteBuffer to write
    public init(byteBuffer: ByteBuffer) {
        self.init(contentLength: byteBuffer.readableBytes) { writer in try await writer.write(byteBuffer) }
    }

    /// Initialise HBResponseBody with an AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: ByteBuffer AsyncSequence
    public init<BufferSequence: AsyncSequence & Sendable>(asyncSequence: BufferSequence) where BufferSequence.Element == ByteBuffer {
        self.init { writer in
            for try await buffer in asyncSequence {
                try await writer.write(buffer)
            }
        }
    }
}
