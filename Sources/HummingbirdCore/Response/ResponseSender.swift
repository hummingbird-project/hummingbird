//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import BasicContainers
public import HTTPAPIs
public import HTTPTypes
public import NIOCore
public import NIOHTTPTypes
public import Synchronization

public struct ResponseSender: HTTPResponseSender, ~Copyable {
    @usableFromInline
    final class WriterState: Sendable {
        @usableFromInline
        struct Wrapped: ~Copyable {
            @usableFromInline
            var finishedWriting: Bool = false
        }

        @usableFromInline
        let wrapped: Mutex<Wrapped> = .init(.init())
    }

    public struct Writer: CallerAsyncWriter, ~Copyable {
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

        public mutating func write(
            buffer: ByteBuffer
        ) async throws(WriteFailure) {
            try await self.writer.write(.body(buffer))
        }

        public mutating func write(
            contentsOf parts: some Sequence<HTTPResponsePart>
        ) async throws(WriteFailure) {
            try await self.writer.write(contentsOf: parts)
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
    init(
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
        try await sendAndFinish(response, buffer: ByteBuffer(draining: &buffer), trailer: trailer)
    }

    @inlinable
    nonisolated(nonsending) public consuming func sendAndFinish(
        _ response: HTTPResponse,
        buffer: ByteBuffer,
        trailer: HTTPFields?
    ) async throws {
        if buffer.readableBytes == 0 {
            try await self.writer.write(contentsOf: [.head(response), .end(trailer)])
        } else {
            try await self.writer.write(contentsOf: [.head(response), .body(buffer), .end(trailer)])
        }
        self.writerState.wrapped.withLock { $0.finishedWriting = true }
    }
}
