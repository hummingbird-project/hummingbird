//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPAPIs
public import HTTPTypes
public import NIOCore
public import NIOHTTPTypes

/// ResponseWriter that writes directly to AsyncChannel
@available(hummingbird 3.0, *)
public struct ResponseWriter: ~Copyable {
    @usableFromInline
    var sender: ResponseSender

    init(_ sender: consuming ResponseSender) {
        self.sender = sender
    }

    /// Write HTTP head part and return ``ResponseBodyWriter`` to write response body
    ///
    /// - Parameter head: Response head
    /// - Returns: Response body writer used to write HTTP response body
    @inlinable
    public consuming func writeHead(_ head: HTTPResponse) async throws -> some (ResponseBodyWriter & ~Copyable) {
        let writer = try await self.sender.send(head)
        return RootResponseBodyWriter(writer: writer)
    }

    /// Write Informational HTTP head part
    ///
    /// Calling this with a non informational HTTP response head will cause a precondition error
    /// - Parameter head: Informational response head
    @inlinable
    public func writeInformationalHead(_ head: HTTPResponse) async throws {
        try await self.sender.sendInformational(head)
    }

    /// Write full HTTP response that doesn't include a body
    ///
    /// - Parameter head: Response head
    public consuming func writeResponse(_ head: HTTPResponse) async throws {
        try await self.sender.sendAndFinish(head)
    }

    /// Write a complete HTTP response, using a fast path for ByteBuffer and empty bodies.
    ///
    /// For single-ByteBuffer and empty bodies, head + body + end are sent as a single
    /// batched write (1 encoder pass instead of 3). Streaming and closure-backed bodies
    /// fall through to the standard path.
    ///
    /// - Parameters:
    ///   - head: Response head
    ///   - body: Response body
    @inlinable
    public consuming func write(response head: HTTPResponse, body: consuming ResponseBody) async throws {
        switch body._backing {
        case .byteBuffer(let buf):
            try await self.sender.sendAndFinish(head, buffer: buf, trailer: nil)
        case .empty:
            try await self.sender.sendAndFinish(head)
        case .closure(_, let fn):
            let bodyWriter = try await self.writeHead(head)
            let w: any (ResponseBodyWriter & ~Copyable) = bodyWriter
            try await fn(w)
        }
    }
}

/// ResponseBodyWriter that writes ByteBuffers to AsyncChannel outbound writer
@usableFromInline
struct RootResponseBodyWriter: ResponseBodyWriter, ~Copyable {

    @usableFromInline
    var writer: ResponseSender.Writer

    @usableFromInline
    init(writer: consuming ResponseSender.Writer) {
        self.writer = writer
    }

    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    @inlinable
    mutating func write(_ buffer: ByteBuffer) async throws {
        try await self.writer.write(buffer: buffer)
    }

    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    @inlinable
    mutating func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        try await self.writer.write(contentsOf: buffers.map { .body($0) })
    }

    /// Finish writing body
    /// - Parameter trailingHeaders: Any trailing headers you want to include at end
    @inlinable
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws {
        try await self.writer.finish(finalElement: trailingHeaders)
    }
}
