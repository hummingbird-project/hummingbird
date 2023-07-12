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
    func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void>

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func consume() async throws -> HBStreamerOutput
}

/// Request body streamer. `HBHTTPDecodeHandler` feeds this with ByteBuffers while the Router consumes them
///
/// Can set as @unchecked Sendable as interface functions are only allowed to run on same EventLoop
public final class HBByteBufferStreamer: HBStreamerProtocol {
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

    /// Queue of streamer inputs
    var queue: CircularBuffer<FeedInput>
    /// Queue of promises waiting for streamer inputs.
    var waitingQueue: CircularBuffer<EventLoopPromise<FeedInput>>
    /// back pressure promise
    var backPressurePromise: EventLoopPromise<Void>?
    /// EventLoop everything is running on
    let eventLoop: EventLoop
    /// called every time a ByteBuffer is consumed
    var onConsume: ((HBByteBufferStreamer) -> Void)?
    /// maximum allowed size to upload
    let maxSize: Int
    /// maximum size currently being streamed before back pressure is applied
    let maxStreamingBufferSize: Int
    /// current size in memory
    var currentSize: Int
    /// bytes fed to streamer so far
    var sizeFed: Int
    /// is request streamer finished
    var isFinishedFeeding: Bool
    /// if finished the last result sent
    var finishedResult: FeedInput?

    public init(eventLoop: EventLoop, maxSize: Int, maxStreamingBufferSize: Int? = nil) {
        self.queue = .init()
        self.waitingQueue = .init()
        self.backPressurePromise = nil
        self.eventLoop = eventLoop
        self.sizeFed = 0
        self.currentSize = 0
        self.maxSize = maxSize
        self.maxStreamingBufferSize = maxStreamingBufferSize ?? maxSize
        self.onConsume = nil
        self.isFinishedFeeding = false
        self.finishedResult = nil
    }

    /// Feed a ByteBuffer to the request, while applying back pressure
    /// - Parameter result: Bytebuffer or end tag
    public func feed(buffer: ByteBuffer) -> EventLoopFuture<Void> {
        if self.eventLoop.inEventLoop {
            return self._feed(buffer: buffer)
        } else {
            return self.eventLoop.flatSubmit {
                self._feed(buffer: buffer)
            }
        }
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    private func _feed(buffer: ByteBuffer) -> EventLoopFuture<Void> {
        self.eventLoop.assertInEventLoop()
        if let backPressurePromise = backPressurePromise {
            return backPressurePromise.futureResult.always { _ in
                self._feed(.byteBuffer(buffer))
            }
        } else {
            self._feed(.byteBuffer(buffer))
            return self.eventLoop.makeSucceededVoidFuture()
        }
    }

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    public func feed(_ result: FeedInput) {
        if self.eventLoop.inEventLoop {
            self._feed(result)
        } else {
            self.eventLoop.execute {
                self._feed(result)
            }
        }
    }

    /// Feed a ByteBuffer to the stream
    /// - Parameter result: Bytebuffer or end tag
    private func _feed(_ result: FeedInput) {
        // don't add more results to queue if we are finished
        guard self.isFinishedFeeding == false else { return }

        self.eventLoop.assertInEventLoop()

        switch result {
        case .byteBuffer(let byteBuffer):
            self.sizeFed += byteBuffer.readableBytes
            self.currentSize += byteBuffer.readableBytes
            if self.currentSize > self.maxStreamingBufferSize {
                self.backPressurePromise = self.eventLoop.makePromise()
            }
            if self.sizeFed > self.maxSize {
                self._feed(.error(HBHTTPError(.payloadTooLarge)))
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
    ///
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        if self.eventLoop.inEventLoop {
            return self.consume().hop(to: eventLoop)
        } else {
            return self.eventLoop.flatSubmit {
                self.consume()
            }.hop(to: eventLoop)
        }
    }

    /// Consume the request body, calling `process` on each buffer until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    ///   - process: Closure to call to process ByteBuffer
    public func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        func _consumeAll(_ count: Int) {
            self.consume().whenComplete { result in
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
                                self.eventLoop.execute {
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
        self.eventLoop.execute {
            _consumeAll(0)
        }
        return promise.futureResult
    }

    /// Consume the request body, but ignore contents
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    func drop() -> EventLoopFuture<Void> {
        self.eventLoop.assertInEventLoop()
        self.isFinishedFeeding = true

        let promise = self.eventLoop.makePromise(of: Void.self)
        func _dropAll() {
            self.consume(on: self.eventLoop).map { output in
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

    /// Consume what has been fed to the request
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed an end tag
    func consume() -> EventLoopFuture<HBStreamerOutput> {
        if let finishedResult = self.finishedResult {
            return self.eventLoop.makeCompletedFuture(finishedResult.streamerOutputResult)
        }
        // function for consuming feed input
        func _consume(input: FeedInput) -> Result<HBStreamerOutput, Error> {
            switch input {
            case .byteBuffer(let buffer):
                self.currentSize -= buffer.readableBytes
                if self.currentSize < self.maxStreamingBufferSize {
                    self.backPressurePromise?.succeed(())
                }
            case .end:
                assert(self.currentSize == 0)
                self.finishedResult = input
            default:
                self.finishedResult = input
            }
            self.onConsume?(self)
            return input.streamerOutputResult
        }
        self.eventLoop.assertInEventLoop()
        // if there is a result on the queue consume that otherwise create
        // a promise and add it to the waiting queue and once that promise
        // is complete consume the result
        if let result = self.queue.popFirst() {
            return self.eventLoop.makeCompletedFuture(_consume(input: result))
        } else {
            let promise = self.eventLoop.makePromise(of: FeedInput.self)
            self.waitingQueue.append(promise)
            return promise.futureResult.flatMapResult(_consume)
        }
    }

    /// Collate the request body into one ByteBuffer
    /// - Parameter maxSize: Maximum size for the resultant ByteBuffer
    /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
    func collate(maxSize: Int) -> EventLoopFuture<ByteBuffer?> {
        let promise = self.eventLoop.makePromise(of: ByteBuffer?.self)
        var completeBuffer: ByteBuffer?
        func _consumeAll(size: Int) {
            self.consume().whenComplete { result in
                switch result {
                case .success(.byteBuffer(var buffer)):
                    let size = size + buffer.readableBytes
                    if size > maxSize {
                        promise.fail(HBHTTPError(.payloadTooLarge))
                    }
                    if completeBuffer != nil {
                        completeBuffer!.writeBuffer(&buffer)
                    } else {
                        completeBuffer = buffer
                    }
                    _consumeAll(size: size)

                case .success(.end):
                    promise.succeed(completeBuffer)

                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        _consumeAll(size: 0)
        return promise.futureResult
    }
}

/// Streamer class initialized with a single ByteBuffer.
///
/// Required for the situation where the user wants to stream but has been provided
/// with a single ByteBuffer
final class HBStaticStreamer: HBStreamerProtocol {
    var byteBuffer: ByteBuffer

    init(_ byteBuffer: ByteBuffer) {
        self.byteBuffer = byteBuffer
    }

    func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        return eventLoop.submit {
            guard let output = self.byteBuffer.readSlice(length: self.byteBuffer.readableBytes) else {
                return .end
            }
            if output.readableBytes == 0 {
                return .end
            }
            return .byteBuffer(output)
        }
    }

    func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        return eventLoop.flatSubmit {
            guard let output = self.byteBuffer.readSlice(length: self.byteBuffer.readableBytes) else {
                return eventLoop.makeSucceededVoidFuture()
            }
            return process(output)
        }
    }
}

extension HBByteBufferStreamer: @unchecked Sendable {}
extension HBStaticStreamer: @unchecked Sendable {}
