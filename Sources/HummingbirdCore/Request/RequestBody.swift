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
            return HBStreamedRequestBody(byteBuffer: buffer).makeAsyncIterator()
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

    enum _Backing {
        case nioAsyncChannel(UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>)
        case producer(Producer)
    }
    private let _backing: _Backing
    private let alreadyIterated: NIOLockedValueBox<Bool>

    /// Initialize HBStreamedRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    init(_ backing: _Backing) {
        self._backing = backing
        self.alreadyIterated = .init(false)
    }

    /// Initialize HBStreamedRequestBody from AsyncIterator of a NIOAsyncChannelInboundStream
    convenience init(iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator) {
        self.init(.nioAsyncChannel(.init(iterator)))
    }

    /// Async Iterator for HBStreamedRequestBody
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = ByteBuffer
        enum _Backing {
            case nioAsyncChannel(NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator)
            case producer(Producer.AsyncIterator)
        }
        private let _backing: _Backing
        private var done: Bool

        init(iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator, done: Bool = false) {
            self._backing = .nioAsyncChannel(iterator)
            self.done = done
        }

        init(iterator: Producer.AsyncIterator, done: Bool = false) {
            self._backing = .producer(iterator)
            self.done = done
        }

        public mutating func next() async throws -> ByteBuffer? {
            if self.done { return nil }
            switch self._backing {
            case .producer(let producer):
                return try await producer.next()
            case .nioAsyncChannel(var httpPartIterator):
                // if we are still expecting parts and the iterator finishes.
                // In this case I think we can just assume we hit an .end
                guard let part = try await httpPartIterator.next() else { return nil }
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
        switch self._backing {
        case .nioAsyncChannel(let iterator):
            return AsyncIterator(iterator: iterator.wrappedValue, done: done)
        case .producer(let producer):
            return AsyncIterator(iterator: producer.makeAsyncIterator(), done: done)
        }
    }
}

/// Request stream with backpressure
extension HBStreamedRequestBody {
    @usableFromInline
    typealias Producer = NIOThrowingAsyncSequenceProducer<
        ByteBuffer, 
        any Error, 
        NIOAsyncSequenceProducerBackPressureStrategies.HighLowWatermark,
        Delegate
    >

    @usableFromInline
    final class Delegate: NIOAsyncSequenceProducerDelegate {
        let checkedContinuation: NIOLockedValueBox<CheckedContinuation<Void, Never>?>
        init() {
            self.checkedContinuation = .init(nil)
        }

        @usableFromInline
        func setContinuation(_ cont: CheckedContinuation<Void, Never>) {
            checkedContinuation.withLockedValue {
                $0 = cont
            }
        }

        @usableFromInline
        func produceMore() {
            checkedContinuation.withLockedValue {
                if let checkedContinuation = $0 {
                    checkedContinuation.resume()
                    $0 = nil
                }
            }
        }

        @usableFromInline
        func didTerminate() {
            checkedContinuation.withLockedValue {
                if let checkedContinuation = $0 {
                    checkedContinuation.resume()
                    $0 = nil
                }
            }
        }
    }

    /// A source used for driving a ``NIOAsyncChannelInboundStream`` during tests.
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
        /// - Parameter element: The element to yield to the inbound stream.
        @inlinable
        public func yield(_ element: ByteBuffer) async throws {
            if self.waitForProduceMore {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    self.delegate.setContinuation(cont)
                    self.waitForProduceMore = false

                }
            }
            let result = self.source.yield(element)
            if result == .stopProducing {
                self.waitForProduceMore = true
            }
        }

        /// Finished the inbound stream.
        ///
        /// - Parameter error: The error to throw, or nil, to finish normally.
        @inlinable
        public func finish() {
            self.source.finish()
        }

        /// Finished the inbound stream.
        ///
        /// - Parameter error: The error to throw, or nil, to finish normally.
        @inlinable
        public func finish(_ error: Error) {
            self.source.finish(error)
        }
    }

    /// Initialize HBStreamedRequestBody from NIOThrowingAsyncSequenceProducer
    convenience init(producer: Producer) {
        self.init(.producer(producer))
    }

    /// Initialize a HBStreamedRequestBody from a ByteBuffer
    public convenience init(byteBuffer: ByteBuffer) {
        let delegate = Delegate()
        let newSequence = Producer.makeSequence(
            backPressureStrategy: .init(lowWatermark: 2, highWatermark: 4), 
            finishOnDeinit: false, 
            delegate: delegate
        )
        let result = newSequence.source.yield(byteBuffer)
        // we are only pushing one ByteBuffer onto the source so yield should be fine
        assert(result == .produceMore)
        newSequence.source.finish()
        self.init(producer: newSequence.sequence)
    }

    static public func makeRequestBodyStream() -> (HBStreamedRequestBody, Source) {
        let delegate = Delegate()
        let newSequence = Producer.makeSequence(
            backPressureStrategy: .init(lowWatermark: 2, highWatermark: 4), 
            finishOnDeinit: false, 
            delegate: delegate
        )
        return (.init(producer: newSequence.sequence), Source(source: newSequence.source, delegate: delegate))
    }
}
