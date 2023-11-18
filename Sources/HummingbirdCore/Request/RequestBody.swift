//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AsyncAlgorithms
import NIOCore
import NIOHTTP1

public enum HBRequestBody: Sendable, AsyncSequence {
    case byteBuffer(ByteBuffer)
    case stream(HBStreamedRequestBody)

    public typealias Element = ByteBuffer
    public typealias AsyncIterator = HBStreamedRequestBody.AsyncIterator

    public func makeAsyncIterator() -> HBStreamedRequestBody.AsyncIterator {
        switch self {
        case .byteBuffer:
            /// The server always creates the HBRequestBody as a stream. If it is converted
            /// into a single ByteBuffer it cannot be treated as a stream after that
            preconditionFailure("Cannot convert collapsed request body back into a sequence")
        case .stream(let streamer):
            return streamer.makeAsyncIterator()
        }
    }

    /// Return new HBRequestBody as a single ByteBuffer
    public func collate(maxSize: Int) async throws -> HBRequestBody {
        switch self {
        case .byteBuffer:
            return self
        case .stream(let streamer):
            return try .byteBuffer(await streamer.collect(upTo: maxSize))
        }
    }
}

/// A type that represents an HTTP request body.
public struct HBStreamedRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = ByteBuffer

        fileprivate var underlyingIterator: AsyncThrowingChannel<ByteBuffer, Error>.AsyncIterator

        public mutating func next() async throws -> ByteBuffer? {
            try await self.underlyingIterator.next()
        }
    }

    /// HBRequestBody is internally represented by AsyncThrowingChannel
    private var channel: AsyncThrowingChannel<ByteBuffer, Error>

    /// Creates a new HTTP request body
    @_spi(HBXCT) public init() {
        self.channel = .init()
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(underlyingIterator: self.channel.makeAsyncIterator())
    }
}

extension HBStreamedRequestBody {
    /// push a single ByteBuffer to the HTTP request body stream
    @_spi(HBXCT) public func send(_ buffer: ByteBuffer) async {
        await self.channel.send(buffer)
    }

    /// pass error to HTTP request body
    @_spi(HBXCT) public func fail(_ error: Error) {
        self.channel.fail(error)
    }

    /// Finish HTTP request body stream
    @_spi(HBXCT) public func finish() {
        self.channel.finish()
    }
}
