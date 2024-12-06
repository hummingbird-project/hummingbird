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

import Collections
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes

/// Request Body
///
/// Can be either a stream of ByteBuffers or a single ByteBuffer
public struct RequestBody: Sendable, AsyncSequence {
    @usableFromInline
    internal enum _Backing: Sendable {
        case byteBuffer(ByteBuffer)
        case nioAsyncChannelRequestBody(NIOAsyncChannelRequestBody)
        case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>)
    }

    @usableFromInline
    internal let _backing: _Backing

    @usableFromInline
    init(_ backing: _Backing) {
        self._backing = backing
    }

    ///  Initialise ``RequestBody`` from ByteBuffer
    /// - Parameter buffer: ByteBuffer
    @inlinable
    public init(buffer: ByteBuffer) {
        self.init(.byteBuffer(buffer))
    }

    ///  Initialise ``RequestBody`` from AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: AsyncSequence
    @inlinable
    package init(nioAsyncChannelInbound: NIOAsyncChannelRequestBody) {
        self.init(.nioAsyncChannelRequestBody(nioAsyncChannelInbound))
    }

    ///  Initialise ``RequestBody`` from AsyncSequence of ByteBuffers
    /// - Parameter asyncSequence: AsyncSequence
    @inlinable
    public init<AS: AsyncSequence & Sendable>(asyncSequence: AS) where AS.Element == ByteBuffer {
        self.init(.anyAsyncSequence(.init(asyncSequence)))
    }
}

/// AsyncSequence protocol requirements
extension RequestBody {
    public typealias Element = ByteBuffer

    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        internal enum _Backing {
            case byteBuffer(ByteBuffer)
            case nioAsyncChannelRequestBody(NIOAsyncChannelRequestBody.AsyncIterator)
            case anyAsyncSequence(AnyAsyncSequence<ByteBuffer>.AsyncIterator)
            case done
        }

        @usableFromInline
        var _backing: _Backing

        @usableFromInline
        init(_ backing: _Backing) {
            self._backing = backing
        }

        @inlinable
        public mutating func next() async throws -> ByteBuffer? {
            switch self._backing {
            case .byteBuffer(let buffer):
                self._backing = .done
                return buffer

            case .nioAsyncChannelRequestBody(var iterator):
                let next = try await iterator.next()
                self._backing = .nioAsyncChannelRequestBody(iterator)
                return next

            case .anyAsyncSequence(let iterator):
                return try await iterator.next()

            case .done:
                return nil
            }
        }
    }

    @inlinable
    public func makeAsyncIterator() -> AsyncIterator {
        switch self._backing {
        case .byteBuffer(let buffer):
            return .init(.byteBuffer(buffer))
        case .nioAsyncChannelRequestBody(let requestBody):
            return .init(.nioAsyncChannelRequestBody(requestBody.makeAsyncIterator()))
        case .anyAsyncSequence(let stream):
            return .init(.anyAsyncSequence(stream.makeAsyncIterator()))
        }
    }
}

/// Extend RequestBody to create request body streams backed by `NIOThrowingAsyncSequenceProducer`.
extension RequestBody {
    @usableFromInline
    typealias Producer = NIOThrowingAsyncSequenceProducer<
        ByteBuffer,
        any Error,
        NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark,
        Delegate
    >

    /// Delegate for NIOThrowingAsyncSequenceProducer
    @usableFromInline
    final class Delegate: NIOAsyncSequenceProducerDelegate, Sendable {
        let checkedContinuations: NIOLockedValueBox<Deque<CheckedContinuation<Void, Never>>>

        @usableFromInline
        init() {
            self.checkedContinuations = .init([])
        }

        @usableFromInline
        func produceMore() {
            self.checkedContinuations.withLockedValue {
                if let cont = $0.popFirst() {
                    cont.resume()
                }
            }
        }

        @usableFromInline
        func didTerminate() {
            self.checkedContinuations.withLockedValue {
                while let cont = $0.popFirst() {
                    cont.resume()
                }
            }
        }

        @usableFromInline
        func waitForProduceMore() async {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                self.checkedContinuations.withLockedValue {
                    $0.append(cont)
                }
            }
        }
    }

    /// A source used for driving a ``RequestBody`` stream.
    public final class Source: Sendable {
        @usableFromInline
        let source: Producer.Source
        @usableFromInline
        let delegate: Delegate
        @usableFromInline
        let waitForProduceMore: NIOLockedValueBox<Bool>

        @usableFromInline
        init(source: Producer.Source, delegate: Delegate) {
            self.source = source
            self.delegate = delegate
            self.waitForProduceMore = .init(false)
        }

        /// Yields the element to the inbound stream.
        ///
        /// This function implements back pressure in that it will wait if the producer
        /// sequence indicates the Source should produce more ByteBuffers.
        ///
        /// - Parameter element: The element to yield to the inbound stream.
        @inlinable
        public func yield(_ element: ByteBuffer) async throws {
            // if previous call indicated we should stop producing wait until the delegate
            // says we can start producing again
            if self.waitForProduceMore.withLockedValue({ $0 }) {
                await self.delegate.waitForProduceMore()
                self.waitForProduceMore.withLockedValue { $0 = false }
            }
            let result = self.source.yield(element)
            if result == .stopProducing {
                self.waitForProduceMore.withLockedValue { $0 = true }
            }
        }

        /// Finished the inbound stream.
        @inlinable
        public func finish() {
            self.source.finish()
        }

        /// Finished the inbound stream.
        ///
        /// - Parameter error: The error to throw
        @inlinable
        public func finish(_ error: Error) {
            self.source.finish(error)
        }
    }

    ///  Make a new ``RequestBody`` stream
    /// - Returns: The new `RequestBody` and a source to yield ByteBuffers to the `RequestBody`.
    @inlinable
    public static func makeStream() -> (RequestBody, Source) {
        let delegate = Delegate()
        let newSequence = Producer.makeSequence(
            backPressureStrategy: .init(lowWatermark: 2, highWatermark: 4),
            finishOnDeinit: false,
            delegate: delegate
        )
        return (.init(asyncSequence: newSequence.sequence), Source(source: newSequence.source, delegate: delegate))
    }
}

/// Request body that is a stream of ByteBuffers sourced from a NIOAsyncChannelInboundStream.
///
/// This is a unicast async sequence that allows a single iterator to be created.
@usableFromInline
package struct NIOAsyncChannelRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer
    public typealias InboundStream = NIOAsyncChannelInboundStream<HTTPRequestPart>

    @usableFromInline
    internal let underlyingIterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>
    @usableFromInline
    internal let alreadyIterated: NIOLockedValueBox<Bool>

    /// Initialize NIOAsyncChannelRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    @inlinable
    public init(iterator: InboundStream.AsyncIterator) {
        self.underlyingIterator = .init(iterator)
        self.alreadyIterated = .init(false)
    }

    /// Async Iterator for NIOAsyncChannelRequestBody
    public struct AsyncIterator: AsyncIteratorProtocol {
        @usableFromInline
        internal var underlyingIterator: InboundStream.AsyncIterator
        @usableFromInline
        internal var done: Bool

        @inlinable
        init(underlyingIterator: InboundStream.AsyncIterator, done: Bool = false) {
            self.underlyingIterator = underlyingIterator
            self.done = done
        }

        @inlinable
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

    @inlinable
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
