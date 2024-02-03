//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes

/// Request Body
///
/// Can be either a stream of ByteBuffers or a single ByteBuffer
public enum HBRequestBody: Sendable, AsyncSequence {
    case byteBuffer(ByteBuffer)
    case stream(HBStreamedRequestBody)

    public typealias Element = ByteBuffer
    public typealias AsyncIterator = HBStreamedRequestBody.AsyncIterator

    public func makeAsyncIterator() -> HBStreamedRequestBody.AsyncIterator {
        switch self {
        case .byteBuffer(let buffer):
            let (stream, source) = NIOAsyncChannelInboundStream<HTTPRequestPart>.makeTestingStream()
            source.yield(.body(buffer))
            source.finish()
            return HBStreamedRequestBody(iterator: stream.makeAsyncIterator()).makeAsyncIterator()
        case .stream(let streamer):
            return streamer.makeAsyncIterator()
        }
    }

    /// Return as a single ByteBuffer. This function is required as `ByteBuffer.collect(upTo:)`
    /// assumes the request body can be iterated.
    public func collate(maxSize: Int) async throws -> ByteBuffer {
        switch self {
        case .byteBuffer(let buffer):
            return buffer
        case .stream:
            return try await collect(upTo: maxSize)
        }
    }
}

/// Request body that is a stream of ByteBuffers.
///
/// This is a unicast async sequence that allows a single iterator to be created.
public final class HBStreamedRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer
    public typealias InboundStream = NIOAsyncChannelInboundStream<HTTPRequestPart>

    private let underlyingIterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>
    private let alreadyIterated: NIOLockedValueBox<Bool>

    /// Initialize HBStreamedRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    public init(iterator: InboundStream.AsyncIterator) {
        self.underlyingIterator = .init(iterator)
        self.alreadyIterated = .init(false)
    }

    /// Async Iterator for HBStreamedRequestBody
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = ByteBuffer

        private var underlyingIterator: InboundStream.AsyncIterator
        private var done: Bool

        init(underlyingIterator: InboundStream.AsyncIterator, done: Bool = false) {
            self.underlyingIterator = underlyingIterator
            self.done = done
        }

        public mutating func next() async throws -> ByteBuffer? {
            if self.done { return nil }
            // if we are still expecting parts and the iterator finishes.
            // In this case I think we can just assume we hit an .end
            guard let part = try await self.underlyingIterator.next() else { return nil }
            switch part {
            case .body(let buffer):
                return buffer
            case .end:
                self.done = true
                return nil
            default:
                throw HTTPChannelError.unexpectedHTTPPart(part)
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        // verify if an iterator has already been created. If it has then create an
        // iterator that returns nothing. This could be a precondition failure (currently
        // an assert) as you should not be allowed to do this.
        let done = self.alreadyIterated.withLockedValue {
            assert($0 == false, "Can only create iterator from request body once")
            let done = $0
            $0 = true
            return done
        }
        return AsyncIterator(underlyingIterator: self.underlyingIterator.wrappedValue, done: done)
    }
}
