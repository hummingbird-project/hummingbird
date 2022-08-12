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
public enum HBStreamerOutput: HBSendable {
    case byteBuffer(ByteBuffer)
    case end
}

public protocol HBStreamerProtocol: HBSendable {
    /// Consume what has been fed to the streamer
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to the request body
    ///     and whether we have consumed everything
    func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput>

    /// Consume ByteBuffers until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
    func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void>

    #if compiler(>=5.5) && canImport(_Concurrency)

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func consume() async throws -> HBStreamerOutput

    #endif // compiler(>=5.5) && canImport(_Concurrency)
}

/// Request body streamer. `HBHTTPDecodeHandler` feeds this with ByteBuffers while the Router consumes them
///
/// Can set as @unchecked Sendable as interface functions are only allowed to run on same EventLoop
public final class HBByteBufferStreamer: HBStreamerProtocol {
    public enum StreamerError: Swift.Error {
        case bodyDropped
    }

    /// Values we can feed the streamer with
    public enum FeedInput {
        case byteBuffer(ByteBuffer)
        case error(Error)
        case end
    }

    /// Queue of promises for each ByteBuffer fed to the streamer. Last entry is always waiting for the next buffer or end tag
    var queue: CircularBuffer<EventLoopPromise<HBStreamerOutput>>
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
    var isFinished: Bool

    public init(eventLoop: EventLoop, maxSize: Int, maxStreamingBufferSize: Int? = nil) {
        self.queue = .init()
        self.backPressurePromise = nil
        self.queue.append(eventLoop.makePromise())
        self.eventLoop = eventLoop
        self.sizeFed = 0
        self.currentSize = 0
        self.maxSize = maxSize
        self.maxStreamingBufferSize = maxStreamingBufferSize ?? maxSize
        self.onConsume = nil
        self.isFinished = false
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

    /// Feed a ByteBuffer to the request
    /// - Parameter result: Bytebuffer or end tag
    private func _feed(_ result: FeedInput) {
        self.eventLoop.assertInEventLoop()

        // queue most have at least one promise on it, or something has gone wrong
        assert(self.queue.last != nil)
        let promise = self.queue.last!

        switch result {
        case .byteBuffer(let byteBuffer):
            // don't add more ByteBuffers to queue if we are finished
            guard self.isFinished == false else { return }

            self.sizeFed += byteBuffer.readableBytes
            self.currentSize += byteBuffer.readableBytes
            if self.currentSize > self.maxStreamingBufferSize {
                self.backPressurePromise = self.eventLoop.makePromise()
            }
            if self.sizeFed > self.maxSize {
                self.isFinished = true
                promise.fail(HBHTTPError(.payloadTooLarge))
            } else {
                self.queue.append(self.eventLoop.makePromise())
                promise.succeed(.byteBuffer(byteBuffer))
            }
        case .error(let error):
            self.isFinished = true
            promise.fail(error)
        case .end:
            guard self.isFinished == false else { return }
            self.isFinished = true
            promise.succeed(.end)
        }
    }

    /// Consume what has been fed to the request
    /// - Parameter eventLoop: EventLoop to return future on
    /// - Returns: Returns an EventLoopFuture that will be fulfilled with array of ByteBuffers that has so far been fed to th request body
    ///     and whether we have consumed everything
    public func consume(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        self.eventLoop.flatSubmit {
            self.consume()
        }.hop(to: eventLoop)
    }

    /// Consume the request body, calling `process` on each buffer until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    ///   - process: Closure to call to process ByteBuffer
    public func consumeAll(on eventLoop: EventLoop, _ process: @escaping (ByteBuffer) -> EventLoopFuture<Void>) -> EventLoopFuture<Void> {
        let promise = self.eventLoop.makePromise(of: Void.self)
        func _consumeAll() {
            self.consume().whenComplete { result in
                switch result {
                case .success(.byteBuffer(let buffer)):
                    process(buffer).whenComplete { result in
                        switch result {
                        case .failure(let error):
                            promise.fail(error)
                        case .success:
                            _consumeAll()
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
            _consumeAll()
        }
        return promise.futureResult
    }

    /// Consume the request body, but ignore contents
    /// - Returns: EventLoopFuture that will be fulfilled when all ByteBuffers have been consumed
    /// - Parameters:
    ///   - eventLoop: EventLoop to run on
    func drop() -> EventLoopFuture<Void> {
        self.eventLoop.assertInEventLoop()
        self.isFinished = true

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
        if self.queue.last != nil {
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
        self.eventLoop.assertInEventLoop()
        assert(self.queue.first != nil)
        let promise = self.queue.first!
        return promise.futureResult.map { result in
            _ = self.queue.popFirst()

            switch result {
            case .byteBuffer(let buffer):
                self.currentSize -= buffer.readableBytes
                if self.currentSize < self.maxStreamingBufferSize {
                    self.backPressurePromise?.succeed(())
                }
            case .end:
                assert(self.currentSize == 0)
            }
            self.onConsume?(self)
            return result
        }
    }

    /// Consume the request body until you receive an end tag
    /// - Returns: EventLoopFuture that will be fulfilled when all buffers are consumed
    func consumeAll() -> EventLoopFuture<ByteBuffer?> {
        self.eventLoop.assertInEventLoop()
        let promise = self.eventLoop.makePromise(of: ByteBuffer?.self)
        var completeBuffer: ByteBuffer?
        func _consumeAll() {
            self.consume().whenComplete { result in
                switch result {
                case .success(.byteBuffer(var buffer)):
                    if completeBuffer != nil {
                        completeBuffer!.writeBuffer(&buffer)
                    } else {
                        completeBuffer = buffer
                    }
                    _consumeAll()

                case .success(.end):
                    promise.succeed(completeBuffer)

                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        _consumeAll()
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

#if compiler(>=5.6)
extension HBByteBufferStreamer: @unchecked Sendable {}
extension HBStaticStreamer: @unchecked Sendable {}
#endif
