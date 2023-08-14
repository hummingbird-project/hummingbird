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

import Foundation
import NIOConcurrencyHelpers
import NIOCore

/// Values returned when we consume the contents of the streamer
public enum HBStreamerOutput: Sendable, Equatable {
    case byteBuffer(ByteBuffer)
    case end
}

/// Protocol for objects providing a stream of ByteBuffers
public protocol HBStreamerProtocol: Sendable {
    /// Consume what has been fed to the streamer
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed everything
    func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput>

    /// Consume ByteBuffers until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
    func consumeAll(on eventLoop: EventLoop, _ process: @escaping @Sendable (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void>

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func consume() async throws -> HBStreamerOutput
}

/// Request body streamer. `HBHTTPDecodeHandler` feeds this with ByteBuffers while the Router consumes them
///
/// Can set as @unchecked Sendable as interface functions are only allowed to run on same EventLoop
public final class HBByteBufferStreamer: HBStreamerProtocol, Sendable {
    public enum StreamerError: Swift.Error {
        case bodyDropped
    }

    /// Values we can feed the streamer with
    public enum FeedInput: Sendable {
        case byteBuffer(ByteBuffer)
        case error(Error)
        case end

        var streamerOutputResult: Result<HBStreamerOutput, Error> {
            switch self {
            case .byteBuffer(let buffer):
                return .success(.byteBuffer(buffer))
            case .end:
                return .success(.end)
            case .error(let error):
                return .failure(error)
            }
        }
    }

    class InternalState {
        init(
            queue: CircularBuffer<FeedInput>,
            waitingQueue: CircularBuffer<EventLoopPromise<FeedInput>>,
            backPressurePromise: EventLoopPromise<Void>? = nil,
            onConsume: ((InternalState) -> Void)? = nil,
            currentSize: Int,
            sizeFed: Int,
            isFinishedFeeding: Bool,
            finishedResult: FeedInput? = nil,
            maxSize: Int,
            maxStreamingBufferSize: Int
        ) {
            self.queue = queue
            self.waitingQueue = waitingQueue
            self.backPressurePromise = backPressurePromise
            self.onConsume = onConsume
            self.currentSize = currentSize
            self.sizeFed = sizeFed
            self.isFinishedFeeding = isFinishedFeeding
            self.finishedResult = finishedResult
            self.maxSize = maxSize
            self.maxStreamingBufferSize = maxStreamingBufferSize
        }

        /// Queue of streamer inputs
        var queue: CircularBuffer<FeedInput>
        /// Queue of promises waiting for streamer inputs.
        var waitingQueue: CircularBuffer<EventLoopPromise<FeedInput>>
        /// back pressure promise
        var backPressurePromise: EventLoopPromise<Void>?
        /// called every time a ByteBuffer is consumed
        var onConsume: ((InternalState) -> Void)?
        /// current size in memory
        var currentSize: Int
        /// bytes fed to streamer so far
        var sizeFed: Int
        /// is request streamer finished
        var isFinishedFeeding: Bool
        /// if finished the last result sent
        var finishedResult: FeedInput?
        /// maximum allowed size to upload
        let maxSize: Int
        /// maximum size currently being streamed before back pressure is applied
        let maxStreamingBufferSize: Int

        /// Feed a ByteBuffer to the request
        /// - Parameter result: Bytebuffer or end tag
        func feed(buffer: ByteBuffer, eventLoop: EventLoop) -> EventLoopFuture<Void> {
            if let backPressurePromise = backPressurePromise {
                let loopBoundSelf = NIOLoopBound(self, eventLoop: eventLoop)
                return backPressurePromise.futureResult.always { _ in
                    loopBoundSelf.value.feed(.byteBuffer(buffer), eventLoop: eventLoop)
                }
            } else {
                self.feed(.byteBuffer(buffer), eventLoop: eventLoop)
                return eventLoop.makeSucceededVoidFuture()
            }
        }

        /// Feed a ByteBuffer to the stream
        /// - Parameter result: Bytebuffer or end tag
        func feed(_ result: FeedInput, eventLoop: EventLoop) {
            // don't add more results to queue if we are finished
            guard self.isFinishedFeeding == false else { return }

            switch result {
            case .byteBuffer(let byteBuffer):
                self.sizeFed += byteBuffer.readableBytes
                self.currentSize += byteBuffer.readableBytes
                if self.currentSize > self.maxStreamingBufferSize {
                    self.backPressurePromise = eventLoop.makePromise()
                }
                if self.sizeFed > self.maxSize {
                    self.feed(.error(HBHTTPError(.payloadTooLarge)), eventLoop: eventLoop)
                } else {
                    // if there is a promise of the waiting queue then succeed that.
                    // otherwise add feed result to queue
                    if let promise = self.waitingQueue.popFirst() {
                        promise.succeed(result)
                    } else {
                        self.queue.append(result)
                    }
                }
            case .error, .end:
                self.isFinishedFeeding = true
                // if waiting queue has any promises then complete all of those
                // otherwise add feed result to queue
                if self.waitingQueue.count > 0 {
                    for promise in self.waitingQueue {
                        promise.succeed(result)
                    }
                } else {
                    self.queue.append(result)
                }
            }
        }

        /// Consume what has been fed to the request
        /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
        ///     and whether we have consumed an end tag
        func consume(eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
            if let finishedResult = self.finishedResult {
                return eventLoop.makeCompletedFuture(finishedResult.streamerOutputResult)
            }
            // function for consuming feed input
            @Sendable func _consume(input: FeedInput) -> Result<HBStreamerOutput, Error> {
                switch input {
                case .byteBuffer(let buffer):
                    self.currentSize -= buffer.readableBytes
                    if self.currentSize < self.maxStreamingBufferSize {
                        self.backPressurePromise?.succeed(())
                    }
                case .end:
                    let size = self.currentSize
                    assert(size == 0)
                    self.finishedResult = input
                default:
                    self.finishedResult = input
                }
                self.onConsume?(self)
                return input.streamerOutputResult
            }

            // if there is a result on the queue consume that otherwise create
            // a promise and add it to the waiting queue and once that promise
            // is complete consume the result
            if let result = self.queue.popFirst() {
                return eventLoop.makeCompletedFuture(_consume(input: result))
            } else {
                let promise = eventLoop.makePromise(of: FeedInput.self)
                self.waitingQueue.append(promise)
                return promise.futureResult.flatMapResult(_consume)
            }
        }

        /// Consume the request body, calling `process` on each buffer until you receive an end tag
        /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
        /// - Parameters:
        ///   - eventLoop: EventLoop to run on
        ///   - process: Closure to call to process ByteBuffer
        func consumeAll(on eventLoop: EventLoop, _ process: @escaping @Sendable (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
            let promise = eventLoop.makePromise(of: Void.self)
            @Sendable func _consumeAll(_ count: Int) {
                self.consume(eventLoop: eventLoop).whenComplete { result in
                    switch result {
                    case .success(.byteBuffer(let buffer)):
                        process(buffer).whenComplete { result in
                            switch result {
                            case .failure(let error):
                                promise.fail(error)
                            case .success:
                                // after 16 iterations, run via execute to avoid any possible
                                // stack overflows
                                if count > 16 {
                                    eventLoop.execute {
                                        _consumeAll(0)
                                    }
                                } else {
                                    _consumeAll(count + 1)
                                }
                            }
                        }

                    case .success(.end):
                        promise.succeed(())

                    case .failure(let error):
                        promise.fail(error)
                    }
                }
            }
            _consumeAll(0)
            return promise.futureResult
        }

        /// Consume the request body, but ignore contents
        /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
        /// - Parameters:
        ///   - eventLoop: EventLoop to run on
        func drop(eventLoop: EventLoop) -> EventLoopFuture<Void> {
            self.isFinishedFeeding = true

            let promise = eventLoop.makePromise(of: Void.self)
            @Sendable func _dropAll() {
                self.consume(eventLoop: eventLoop).map { output in
                    switch output {
                    case .byteBuffer:
                        _dropAll()

                    case .end:
                        promise.succeed(())
                    }
                }
                .cascadeFailure(to: promise)
            }
            if self.waitingQueue.last != nil {
                _dropAll()
            } else {
                promise.succeed(())
            }
            return promise.futureResult
        }

        /// Collate the request body into one ByteBuffer
        /// - Parameter maxSize: Maximum size for the resultant ByteBuffer
        /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
        func collate(maxSize: Int, eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer?> {
            let promise = eventLoop.makePromise(of: ByteBuffer?.self)
            let completeBuffer: NIOLoopBoundBox<ByteBuffer?> = .init(nil, eventLoop: eventLoop)
            @Sendable func _consumeAll(size: Int) {
                self.consume(eventLoop: eventLoop).whenComplete { result in
                    switch result {
                    case .success(.byteBuffer(var buffer)):
                        let size = size + buffer.readableBytes
                        if size > maxSize {
                            promise.fail(HBHTTPError(.payloadTooLarge))
                        }
                        if completeBuffer.value != nil {
                            completeBuffer.value!.writeBuffer(&buffer)
                        } else {
                            completeBuffer.value = buffer
                        }
                        _consumeAll(size: size)

                    case .success(.end):
                        promise.succeed(completeBuffer.value)

                    case .failure(let error):
                        promise.fail(error)
                    }
                }
            }
            _consumeAll(size: 0)
            return promise.futureResult
        }

        func isBackpressureRequired(_ callback: @escaping () -> Void) -> Bool {
            guard self.currentSize < self.maxStreamingBufferSize else {
                self.onConsume = { streamer in
                    if streamer.currentSize < streamer.maxStreamingBufferSize {
                        callback()
                    }
                }
                return true
            }
            return false
        }
    }

    /// state wrapped in a NIOLoopBoubdBox to ensure state is only ever accessed from eventloop
    internal let state: NIOLoopBoundBox<InternalState>

    public init(eventLoop: EventLoop, maxSize: Int, maxStreamingBufferSize: Int? = nil) {
        self.state = .init(
            .init(
                queue: .init(),
                waitingQueue: .init(),
                backPressurePromise: nil,
                onConsume: nil,
                currentSize: 0,
                sizeFed: 0,
                isFinishedFeeding: false,
                finishedResult: nil,
                maxSize: maxSize,
                maxStreamingBufferSize: maxStreamingBufferSize ?? maxSize
            ),
            eventLoop: eventLoop
        )
    }

    /// Feed a ByteBuffer to the request, while applying back pressure
    /// - Parameter result: Bytebuffer or end tag
    public func feed(buffer: ByteBuffer) -> EventLoopFuture<Void> {
        self.state.runOnLoop { state, eventLoop in
            state.feed(buffer: buffer, eventLoop: eventLoop)
        }
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    public func feed(_ result: FeedInput) {
        self.state.runOnLoop { state, eventLoop in
            state.feed(result, eventLoop: eventLoop)
        }
    }

    /// Consume what has been fed to the request
    ///
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume() -> EventLoopFuture<HBStreamerOutput> {
        self.state.runOnLoop { state, eventLoop in
            state.consume(eventLoop: eventLoop)
        }
    }

    /// Consume what has been fed to the request
    ///
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        self.state.runOnLoop { state, stateEventLoop in
            state.consume(eventLoop: stateEventLoop)
        }.hop(to: eventLoop)
    }

    /// Consume the request body, calling `process` on each buffer until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    ///   - process: Closure to call to process ByteBuffer
    public func consumeAll(_ process: @escaping @Sendable (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        self.state.runOnLoop { state, eventLoop in
            state.consumeAll(on: eventLoop, process)
        }
    }

    /// Consume the request body, calling `process` on each buffer until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    ///   - process: Closure to call to process ByteBuffer
    public func consumeAll(on eventLoop: EventLoop, _ process: @escaping @Sendable (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        self.state.runOnLoop { state, stateEventLoop in
            state.consumeAll(on: stateEventLoop, process)
        }.hop(to: eventLoop)
    }

    /// Consume the request body, but ignore contents
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    func drop() -> EventLoopFuture<Void> {
        self.state.runOnLoop { state, eventLoop in
            state.drop(eventLoop: eventLoop)
        }
    }

    /// Collate the request body into one ByteBuffer
    /// - Parameter maxSize: Maximum size for the resultant ByteBuffer
    /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
    func collate(maxSize: Int) -> EventLoopFuture<ByteBuffer?> {
        self.state.runOnLoop { state, eventLoop in
            state.collate(maxSize: maxSize, eventLoop: eventLoop)
        }
    }

    /// Check if backpressure should be applied and provide callback to be called when it
    /// is no longer needed
    func isBackpressureRequired(_ callback: @escaping () -> Void) -> Bool {
        self.state.value.isBackpressureRequired(callback)
    }
}

/// Streamer class initialized with a single ByteBuffer.
///
/// Required for the situation where the user wants to stream but has been provided
/// with a single ByteBuffer
final class HBStaticStreamer: HBStreamerProtocol, Sendable {
    let byteBuffer: NIOLockedValueBox<ByteBuffer>

    init(_ byteBuffer: ByteBuffer) {
        self.byteBuffer = .init(byteBuffer)
    }

    func consume() -> HBStreamerOutput {
        return self.byteBuffer.withLockedValue { byteBuffer in
            guard let output = byteBuffer.readSlice(length: byteBuffer.readableBytes) else {
                return .end
            }
            if output.readableBytes == 0 {
                return .end
            }
            return .byteBuffer(output)
        }
    }

    func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        return eventLoop.submit {
            return self.consume()
        }
    }

    func consumeAll(on eventLoop: EventLoop, _ process: @escaping @Sendable (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return eventLoop.flatSubmit {
            return self.byteBuffer.withLockedValue { byteBuffer in
                guard let output = byteBuffer.readSlice(length: byteBuffer.readableBytes) else {
                    return eventLoop.makeSucceededVoidFuture()
                }
                return process(output)
            }
        }
    }
}

extension NIOLoopBoundBox {
    /// Run callback on event loop attached to NIOLoopBoundBox
    @discardableResult func runOnLoop<NewValue>(_ callback: @escaping @Sendable (Value, EventLoop) -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
        if self._eventLoop.inEventLoop {
            return callback(self.value, self._eventLoop)
        } else {
            return self._eventLoop.flatSubmit {
                callback(self.value, self._eventLoop)
            }
        }
    }

    /// Run callback on event loop attached to NIOLoopBoundBox
    @discardableResult func runOnLoop<NewValue>(_ callback: @escaping @Sendable (Value, EventLoop) throws -> NewValue) -> EventLoopFuture<NewValue> {
        if self._eventLoop.inEventLoop {
            return _eventLoop.makeCompletedFuture { try callback(self.value, self._eventLoop) }
        } else {
            return self._eventLoop.submit {
                try callback(self.value, self._eventLoop)
            }
        }
    }
}
