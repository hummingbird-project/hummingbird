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

/// A type that represents an HTTP request body.
public struct HBRequestBody: Sendable, AsyncSequence {
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
    public init() {
        self.channel = .init()
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(underlyingIterator: self.channel.makeAsyncIterator())
    }
}

extension HBRequestBody {
    /// push a single ByteBuffer to the HTTP request body stream
    func send(_ buffer: ByteBuffer) async {
        await self.channel.send(buffer)
    }

    /// pass error to HTTP request body
    func fail(_ error: Error) {
        self.channel.fail(error)
    }

    /// Finish HTTP request body stream
    func finish() {
        self.channel.finish()
    }
}
