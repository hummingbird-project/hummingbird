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
                XCTAssertLessThanOrEqual(streamer.currentSize, streamer.maxStreamingBufferSize + blockSize)
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
                XCTAssertLessThanOrEqual(streamer.currentSize, streamer.maxStreamingBufferSize + blockSize)
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
        var consumeBuffer = ByteBuffer()
        return streamer.consumeAll(on: eventLoop) { buffer in
            var buffer = buffer
            consumeBuffer.writeBuffer(&buffer)
            return eventLoop.makeSucceededVoidFuture()
        }.map { consumeBuffer }
    }

    func consumeStreamerWithDelays(_ streamer: HBByteBufferStreamer, eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        var consumeBuffer = ByteBuffer()
        return streamer.consumeAll(on: eventLoop) { buffer in
            var buffer = buffer
            consumeBuffer.writeBuffer(&buffer)
            return eventLoop.scheduleTask(in: .microseconds(Int64.random(in: 0..<100))) {}.futureResult
        }.map { consumeBuffer }
    }

    /// Test can feed and then consume
    func testFeedConsume() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024)

        self.feedStreamer(streamer, buffer: buffer, eventLoop: eventLoop)
        let consumeBuffer = try consumeStreamer(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// Test can feed from not the EventLoop and then consume
    func testFeedOffEventLoop() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024)

        self.feedStreamer(streamer, buffer: buffer)
        let consumeBuffer = try consumeStreamer(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// Test can feed and then consume with back pressure applied
    func testFeedWithBackPressure() throws {
        let buffer = self.randomBuffer(size: 128_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 20 * 1024)

        self.feedStreamerWithBackPressure(streamer, buffer: buffer)
        let consumeBuffer = try consumeStreamer(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// Test can feed and then consume with delays and back pressure applied
    func testFeedWithBackPressureConsumeDelays() throws {
        let buffer = self.randomBuffer(size: 600_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

        self.feedStreamerWithBackPressure(streamer, buffer: buffer)
        let consumeBuffer = try consumeStreamerWithDelays(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// Test can feed and then consume
    func testFeedWithBackPressureAndDelays() throws {
        let buffer = self.randomBuffer(size: 400_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

        self.feedStreamerWithDelays(streamer, buffer: buffer, eventLoop: eventLoop)
        let consumeBuffer = try consumeStreamer(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// Test can feed and then consume
    func testFeedAndConsumeWithDelays() throws {
        let buffer = self.randomBuffer(size: 550_000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 1024 * 1024, maxStreamingBufferSize: 64 * 1024)

        self.feedStreamerWithDelays(streamer, buffer: buffer, eventLoop: eventLoop)
        let consumeBuffer = try consumeStreamerWithDelays(streamer, eventLoop: eventLoop).wait()

        XCTAssertEqual(buffer, consumeBuffer)
    }

    /// test max size works
    func testMaxSize() throws {
        let buffer = self.randomBuffer(size: 60000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 32 * 1024)
        self.feedStreamer(streamer, buffer: buffer)
        XCTAssertThrowsError(try self.consumeStreamer(streamer, eventLoop: eventLoop).wait()) { error in
            switch error {
            case let error as HBHTTPError:
                XCTAssertEqual(error.status, .payloadTooLarge)
            default:
                XCTFail("\(error)")
            }
        }
    }

    /// test error is propagated
    func testError() throws {
        struct MyError: Error {}
        var buffer = self.randomBuffer(size: 10000)
        let eventLoop = self.elg.next()
        let streamer = HBByteBufferStreamer(eventLoop: eventLoop, maxSize: 32 * 1024)

        while buffer.readableBytes > 0 {
            let blockSize = min(buffer.readableBytes, 32 * 1024)
            streamer.feed(.byteBuffer(buffer.readSlice(length: blockSize)!))
        }
        streamer.feed(.error(MyError()))

        XCTAssertThrowsError(try self.consumeStreamer(streamer, eventLoop: eventLoop).wait()) { error in
            switch error {
            case is MyError:
                break
            default:
                XCTFail("\(error)")
            }
        }
    }
}
