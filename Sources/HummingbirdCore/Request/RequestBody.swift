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
public enum HBRequestBody: Sendable, AsyncSequence {
    case byteBuffer(ByteBuffer)
    case stream(HBStreamedRequestBody)

    public typealias Element = ByteBuffer
    public typealias AsyncIterator = HBStreamedRequestBody.AsyncIterator

    public func makeAsyncIterator() -> HBStreamedRequestBody.AsyncIterator {
        switch self {
        case .byteBuffer(let buffer):
            return HBStreamedRequestBody(ByteBufferRequestBody(byteBuffer: buffer)).makeAsyncIterator()
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

    ///  Make a new ``HBRequestBody.stream`` alongside a Source to yield ByteBuffers to it.
    /// - Returns: The new `HBRequestBody`
    public static func makeStream() -> (HBRequestBody, HBStreamedRequestBody.Source) {
        let (stream, source) = HBStreamedRequestBody.makeStream()
        return (.stream(stream), source)
    }
}

/// Request body that is an existential AsyncSequence of ByteBuffers.
public struct HBStreamedRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer
    public typealias AsyncIterator = AnyAsyncSequence<ByteBuffer>.AsyncIterator

    let anyAsyncSequence: AnyAsyncSequence<ByteBuffer>

    init<AS: AsyncSequence>(_ asyncSequence: AS) where AS.Element == ByteBuffer, AS: Sendable {
        self.anyAsyncSequence = .init(asyncSequence)
    }

    public func makeAsyncIterator() -> AnyAsyncSequence<ByteBuffer>.AsyncIterator {
        self.anyAsyncSequence.makeAsyncIterator()
    }
}

extension HBStreamedRequestBody {
    @usableFromInline
    typealias Producer = NIOThrowingAsyncSequenceProducer<
        ByteBuffer,
        any Error,
        NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark,
        Delegate
    >

    /// Delegate for NIOThrowingAsyncSequenceProducer
    @usableFromInline
    final class Delegate: NIOAsyncSequenceProducerDelegate {
        let checkedContinuations: NIOLockedValueBox<Deque<CheckedContinuation<Void, Never>>>
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

    /// A source used for driving a ``HBStreamedRequestBody``.
    public final class Source {
        @usableFromInline
        let source: Producer.Source
        @usableFromInline
        let delegate: Delegate
        @usableFromInline
        var waitForProduceMore: Bool

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
            if self.waitForProduceMore {
                await self.delegate.waitForProduceMore()
                self.waitForProduceMore = false
            }
            let result = self.source.yield(element)
            if result == .stopProducing {
                self.waitForProduceMore = true
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

    ///  Make a new ``HBStreamedRequestBody``
    /// - Returns: The new `HBStreamedRequestBody` and a source to yield ByteBuffers to the `HBStreamedRequestBody`.
    static func makeStream() -> (HBStreamedRequestBody, Source) {
        let delegate = Delegate()
        let newSequence = Producer.makeSequence(
            backPressureStrategy: .init(lowWatermark: 2, highWatermark: 4),
            finishOnDeinit: false,
            delegate: delegate
        )
        return (.init(newSequence.sequence), Source(source: newSequence.source, delegate: delegate))
    }
}

/// Request body that is a stream of ByteBuffers sourced from a NIOAsyncChannelInboundStream.
///
/// This is a unicast async sequence that allows a single iterator to be created.
final class NIOAsyncChannelRequestBody: Sendable, AsyncSequence {
    public typealias Element = ByteBuffer
    public typealias InboundStream = NIOAsyncChannelInboundStream<HTTPRequestPart>

    private let underlyingIterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>
    private let alreadyIterated: NIOLockedValueBox<Bool>

    /// Initialize NIOAsyncChannelRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    public init(iterator: InboundStream.AsyncIterator) {
        self.underlyingIterator = .init(iterator)
        self.alreadyIterated = .init(false)
    }

    /// Async Iterator for NIOAsyncChannelRequestBody
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

/// Request body stream that is a single ByteBuffer
///
/// This is used when converting a ByteBuffer back to a stream of ByteBuffers
struct ByteBufferRequestBody: Sendable, AsyncSequence {
    typealias Element = ByteBuffer

    struct AsyncIterator: AsyncIteratorProtocol {
        var byteBuffer: ByteBuffer
        var iterated: Bool

        init(byteBuffer: ByteBuffer) {
            self.byteBuffer = byteBuffer
            self.iterated = false
        }

        @inlinable
        mutating func next() async throws -> ByteBuffer? {
            guard self.iterated == false else { return nil }
            self.iterated = true
            return self.byteBuffer
        }
    }

    @inlinable
    func makeAsyncIterator() -> AsyncIterator {
        .init(byteBuffer: self.byteBuffer)
    }

    let byteBuffer: ByteBuffer
}
