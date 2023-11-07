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

@testable import HummingbirdCore
import NIOCore
import NIOPosix
import XCTest

class ByteBufferStreamerTests: XCTestCase {
    var elg: EventLoopGroup!

    override func setUp() {
        self.elg = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.elg.syncShutdownGracefully())
    }

    func randomBuffer(size: Int) -> ByteBuffer {
        var data = [UInt8](repeating: 0, count: size)
        data = data.map { _ in UInt8.random(in: 0...255) }
        return ByteBufferAllocator().buffer(bytes: data)
    }

    func feedStreamer(_ streamer: HBByteBufferStreamer, buffer: ByteBuffer) {
        var buffer = buffer
        while buffer.readableBytes > 0 {
            let blockSize = min(buffer.readableBytes, 32 * 1024)
            streamer.feed(.byteBuffer(buffer.readSlice(length: blockSize)!))
        }
        streamer.feed(.end)
    }

    func feedStreamer(_ streamer: HBByteBufferStreamer, buffer: ByteBuffer, eventLoop: EventLoop) {
        var buffer = buffer
        eventLoop.execute {
            while buffer.readableBytes > 0 {
                let blockSize = min(buffer.readableBytes, 32 * 1024)
                streamer.feed(.byteBuffer(buffer.readSlice(length: blockSize)!))
            }
            streamer.feed(.end)
        }
    }

    func feedStreamerWithBackPressure(_ streamer: HBByteBufferStreamer, buffer: ByteBuffer) {
        var buffer = buffer
        func _feed() {
            let blockSize = min(buffer.readableBytes, 32 * 1024)
            streamer.feed(buffer: buffer.readSlice(length: blockSize)!).whenComplete { _ in
                XCTAssertLessThanOrEqual(streamer.state.value.currentSize, streamer.state.value.maxStreamingBufferSize + blockSize)
                if buffer.readableBytes > 0 {
                    _feed()
                } else {
                    streamer.feed(.end)
                }
            }
        }
        _feed()
    }

    func feedStreamerWithDelays(_ streamer: HBByteBufferStreamer, buffer: ByteBuffer, eventLoop: EventLoop) {
        var buffer = buffer
        func _feed() {
            let blockSize = min(buffer.readableBytes, 32 * 1024)
            streamer.feed(buffer: buffer.readSlice(length: blockSize)!).whenComplete { _ in
                XCTAssertLessThanOrEqual(streamer.state.value.currentSize, streamer.state.value.maxStreamingBufferSize + blockSize)
                if buffer.readableBytes > 0 {
                    eventLoop.scheduleTask(in: .microseconds(Int64.random(in: 0..<100_000))) {
                        _feed()
                    }
                } else {
                    streamer.feed(.end)
                }
            }
        }
        _feed()
    }

    func consumeStreamer(_ streamer: HBByteBufferStreamer, eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        let consumeBufferLoopBound = NIOLoopBoundBox(ByteBuffer(), eventLoop: eventLoop)
        return streamer.consumeAll { buffer in
            var buffer = buffer
            consumeBufferLoopBound.value.writeBuffer(&buffer)
            return eventLoop.makeSucceededVoidFuture()
        }.map { consumeBufferLoopBound.value }
    }

    func consumeStreamerWithDelays(_ streamer: HBByteBufferStreamer, eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        let consumeBufferLoopBound = NIOLoopBoundBox(ByteBuffer(), eventLoop: eventLoop)
        return streamer.consumeAll { buffer in
            var buffer = buffer
            consumeBufferLoopBound.value.writeBuffer(&buffer)
            return eventLoop.scheduleTask(in: .microseconds(Int64.random(in: 0..<100))) {}.futureResult
        }.map { consumeBufferLoopBound.value }
    }

    /// Test can feed and then consume
    func testFeedConsume() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()

        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024)

            self.feedStreamer(streamer, buffer: buffer, eventLoop: eventLoop)
            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can feed from not the EventLoop and then consume
    func testFeedOffEventLoop() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024)

            self.feedStreamer(streamer, buffer: buffer, eventLoop: self.elg.next())
            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can feed and then consume with back pressure applied
    func testFeedWithBackPressure() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()

        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 20 * 1024)

            self.feedStreamerWithBackPressure(streamer, buffer: buffer)
            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can feed and then consume with delays and back pressure applied
    func testFeedWithBackPressureConsumeDelays() throws {
        let buffer = self.randomBuffer(size: 600_000)
        let eventLoop = self.elg.next()

        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

            self.feedStreamerWithBackPressure(streamer, buffer: buffer)
            return self.consumeStreamerWithDelays(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can feed and then consume
    func testFeedWithBackPressureAndDelays() throws {
        let buffer = self.randomBuffer(size: 400_000)
        let eventLoop = self.elg.next()

        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

            self.feedStreamerWithDelays(streamer, buffer: buffer, eventLoop: eventLoop)
            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can feed and then consume
    func testFeedAndConsumeWithDelays() throws {
        let buffer = self.randomBuffer(size: 550_000)
        let eventLoop = self.elg.next()
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

            self.feedStreamerWithDelays(streamer, buffer: buffer, eventLoop: eventLoop)
            return self.consumeStreamerWithDelays(streamer, eventLoop: eventLoop).map { consumeBuffer in
                XCTAssertEqual(buffer, consumeBuffer)
            }
        }.wait()
    }

    /// Test can run multiple consumes at same time
    func testConcurrentConsumes() throws {
        let originalBuffer = self.randomBuffer(size: 20000)
        var buffer = originalBuffer
        let eventLoop = self.elg.next()
        let finalBuffer = try eventLoop.flatSubmit { () -> EventLoopFuture<ByteBuffer> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)
            let consumeRequests: [EventLoopFuture<HBStreamerOutput>] = (0..<4).map { _ in streamer.consume() }

            while let slice = buffer.readSlice(length: 5000) {
                _ = streamer.feed(buffer: slice)
            }
            streamer.feed(.end)

            var finalBuffer = ByteBufferAllocator().buffer(capacity: 20000)
            return EventLoopFuture.whenAllSucceed(consumeRequests, on: eventLoop).map { results -> ByteBuffer in
                for result in results {
                    if case .byteBuffer(var buffer) = result {
                        finalBuffer.writeBuffer(&buffer)
                    }
                }
                return finalBuffer
            }
        }.wait()
        XCTAssertEqual(originalBuffer, finalBuffer)
    }

    /// Test can run multiple consumes at same time with feeds behind and ahead
    func testAheadBehindConsumes() throws {
        let originalBuffer = self.randomBuffer(size: 20000)
        var buffer = originalBuffer
        let eventLoop = self.elg.next()
        let finalBuffer = try eventLoop.flatSubmit { () -> EventLoopFuture<ByteBuffer> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)
            var finalBuffer = ByteBufferAllocator().buffer(capacity: 20000)
            var consumeRequests: [EventLoopFuture<HBStreamerOutput>] = (0..<5).map { _ in streamer.consume() }
            while let slice = buffer.readSlice(length: 2000) {
                _ = streamer.feed(buffer: slice)
            }
            streamer.feed(.end)
            let consumeRequests2: [EventLoopFuture<HBStreamerOutput>] = (0..<5).map { _ in streamer.consume() }
            consumeRequests.append(contentsOf: consumeRequests2)
            return EventLoopFuture.whenAllSucceed(consumeRequests, on: eventLoop).map { results -> ByteBuffer in
                for result in results {
                    if case .byteBuffer(var buffer) = result {
                        finalBuffer.writeBuffer(&buffer)
                    }
                }
                return finalBuffer
            }
        }.wait()
        XCTAssertEqual(originalBuffer, finalBuffer)
    }

    /// test max size works
    func testMaxSize() throws {
        let buffer = self.randomBuffer(size: 60000)
        let eventLoop = self.elg.next()
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 32 * 1024)
            self.feedStreamer(streamer, buffer: buffer)
            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { _ in
                XCTFail("Should not get here")
            }.flatMapErrorThrowing { error in
                switch error {
                case let error as HBHTTPError:
                    XCTAssertEqual(error.status, .payloadTooLarge)
                default:
                    XCTFail("\(error)")
                }
            }
        }.wait()
    }

    func testCallingConsumeAfterEnd() throws {
        let buffer = self.randomBuffer(size: 1)
        let eventLoop = self.elg.next()
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 32 * 1024)
            streamer.feed(.byteBuffer(buffer))
            streamer.feed(.end)

            return streamer.consume().flatMap { _ in
                return streamer.consume()
            }.flatMap { (end: HBStreamerOutput) in
                XCTAssertEqual(end, .end)
                return streamer.consume()
            }.map { (end: HBStreamerOutput) in
                XCTAssertEqual(end, .end)
            }
        }.wait()
    }

    /// test error is propagated
    func testError() throws {
        struct MyError: Error {}
        var buffer = self.randomBuffer(size: 10000)
        let eventLoop = self.elg.next()
        try eventLoop.flatSubmit { () -> EventLoopFuture<Void> in
            let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 32 * 1024)

            while buffer.readableBytes > 0 {
                let blockSize = min(buffer.readableBytes, 32 * 1024)
                streamer.feed(.byteBuffer(buffer.readSlice(length: blockSize)!))
            }
            streamer.feed(.error(MyError()))

            return self.consumeStreamer(streamer, eventLoop: eventLoop).map { _ in
                XCTFail("Should not get here")
            }.flatMapErrorThrowing { error in
                switch error {
                case is MyError:
                    break
                default:
                    XCTFail("\(error)")
                }
            }
        }.wait()
    }
}
