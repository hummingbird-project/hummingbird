//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import BasicContainers
import ContainersPreview
public import HTTPAPIs
public import HTTPTypes
public import NIOCore
public import NIOHTTPTypes
public import Synchronization

/// A `CallerAsyncWriter` for writing HTTP responses
public protocol ResponseBodyAsyncWriter: CallerAsyncWriter, ~Copyable
where WriteElement == UInt8, WriteFailure == any Error, FinalElement == HTTPFields? {
}

/// Wrapper for existential ResponseBodyAsyncWriter
public struct AnyResponseBodyAsyncWriter: ~Copyable {
    @usableFromInline
    package init(_ writer: consuming (any ResponseBodyAsyncWriter & ~Copyable)) {
        self.writer = consume writer
    }

    @inlinable
    public mutating nonisolated(nonsending) func write<Buffer>(buffer: inout Buffer) async throws(any Error)
    where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
        try await self.writer!.write(buffer: &buffer)
    }

    @inlinable
    public consuming nonisolated(nonsending) func finish<Buffer>(
        buffer: inout Buffer,
        finalElement: consuming HTTPTypes.HTTPFields? = nil
    ) async throws(any Error)
    where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
        let writer = self.writer.take()!
        try await writer.finish(buffer: &buffer, finalElement: finalElement)
    }

    @inlinable
    public consuming nonisolated(nonsending) func finish(finalElement: consuming HTTPTypes.HTTPFields? = nil) async throws(any Error) {
        let writer = self.writer.take()!
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: finalElement)
    }

    public var writer: (any ResponseBodyAsyncWriter & ~Copyable)?
}

/// HTTPResponseSender that sends an HTTP response using a NIOAsyncChannelOutboundWriter
public struct ResponseSender: HTTPResponseSender, ~Copyable {
    @usableFromInline
    package final class WriterState: Sendable {
        @usableFromInline
        package struct Wrapped: ~Copyable {
            @usableFromInline
            package var finishedWriting: Bool = false
        }

        @usableFromInline
        package let wrapped: Mutex<Wrapped>

        package init() {
            self.wrapped = .init(.init())
        }
    }

    /// ResponseBody AsyncWriter that writes the response body using a NIOAsyncChannelOutboundWriter
    public struct Writer: ResponseBodyAsyncWriter, ~Copyable {
        public typealias WriteElement = UInt8
        public typealias WriteFailure = any Error
        public typealias FinalElement = HTTPFields?

        /// The underlying NIO writer for HTTP response parts.
        let writer: NIOAsyncChannelOutboundWriter<HTTPResponsePart>

        /// State of writer
        let writerState: WriterState

        @usableFromInline
        init(
            writer: NIOAsyncChannelOutboundWriter<HTTPResponsePart>,
            writerState: WriterState
        ) {
            self.writer = writer
            self.writerState = writerState
        }

        public mutating func write(
            buffer: inout some RangeReplaceableContainer<UInt8> & ~Copyable
        ) async throws(WriteFailure) {
            try await self.writer.write(.body(ByteBuffer(draining: &buffer)))
        }

        public consuming func finish(
            buffer: inout some RangeReplaceableContainer<UInt8> & ~Copyable,
            finalElement: consuming HTTPFields?
        ) async throws(WriteFailure) {
            if !buffer.isEmpty {
                try await self.writer.write(.body(ByteBuffer(draining: &buffer)))
            }
            try await self.writer.write(.end(finalElement))
            self.writerState.wrapped.withLock { $0.finishedWriting = true }
        }

        public consuming func finish(
            finalElement: consuming HTTPFields?
        ) async throws(WriteFailure) {
            try await self.writer.write(.end(finalElement))
            self.writerState.wrapped.withLock { $0.finishedWriting = true }
        }
    }

    @usableFromInline
    let writer: NIOAsyncChannelOutboundWriter<HTTPResponsePart>
    @usableFromInline
    let writerState: WriterState

    // Initializes a new response sender.
    @inlinable
    package init(
        writer: NIOAsyncChannelOutboundWriter<HTTPResponsePart>,
        writerState: WriterState
    ) {
        self.writer = writer
        self.writerState = writerState
    }

    @inlinable
    public func sendInformational(_ response: HTTPResponse) async throws {
        precondition(response.status.kind == .informational)
        try await self.writer.write(.head(response))
    }

    @inlinable
    public consuming func send(_ response: HTTPResponse) async throws -> sending Writer {
        precondition(response.status.kind != .informational)
        try await self.writer.write(.head(response))

        return Writer(writer: self.writer, writerState: self.writerState)
    }

    @inlinable
    public consuming func sendAndFinish<Buffer: RangeReplaceableContainer<UInt8> & ~Copyable>(
        _ response: HTTPResponse,
        buffer: inout Buffer,
        trailer: HTTPFields?
    ) async throws where Buffer.Element: ~Copyable {
        if buffer.count == 0 {
            try await self.writer.write(contentsOf: [.head(response), .end(trailer)])
        } else {
            try await self.writer.write(contentsOf: [.head(response), .body(ByteBuffer(draining: &buffer)), .end(trailer)])
        }
        self.writerState.wrapped.withLock { $0.finishedWriting = true }
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
    @available(hummingbird 3.0, *)
    @inlinable
    public consuming func write(response head: HTTPResponse, body: consuming ResponseBody) async throws {
        switch body._backing {
        case .bytes(let buf):
            try await self.sendAndFinish(head, buffer: &buf.value, trailer: nil)
        case .empty:
            try await self.sendAndFinish(head)
        case .closure(_, let fn):
            let bodyWriter = try await self.send(head)
            try await fn(AnyResponseBodyAsyncWriter(bodyWriter))
        }
    }
}
