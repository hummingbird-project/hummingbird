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

import NIOCore

#if compiler(>=5.6)
/// Function returning streamed byte buffer output
public typealias HBStreamCallback = @Sendable (EventLoop) -> EventLoopFuture<HBStreamerOutput>
#else
public typealias HBStreamCallback = (EventLoop) -> EventLoopFuture<HBStreamerOutput>
#endif

/// Response body. Can be a single ByteBuffer, a stream of ByteBuffers or empty
public enum HBResponseBody: HBSendable {
    /// Body stored as a single ByteBuffer
    case byteBuffer(ByteBuffer)
    /// Streamer object supplying byte buffers
    case stream(HBResponseBodyStreamer)
    /// Empty body
    case empty

    /// Construct a `HBResponseBody` from a closure supplying `ByteBuffer`'s.
    ///
    /// This function should supply `.byteBuffer(ByteBuffer)` until there is no more data, at which
    /// point is should return `'end`.
    ///
    /// - Parameter closure: Closure called whenever a new ByteBuffer is needed
    public static func stream(_ streamer: HBStreamerProtocol) -> Self {
        .stream(ResponseByteBufferStreamer(streamer: streamer))
    }

    /// Construct a `HBResponseBody` from a closure supplying `ByteBuffer`'s.
    ///
    /// This function should supply `.byteBuffer(ByteBuffer)` until there is no more data, at which
    /// point is should return `'end`.
    ///
    /// - Parameter closure: Closure called whenever a new ByteBuffer is needed
    public static func streamCallback(_ closure: @escaping HBStreamCallback) -> Self {
        .stream(ResponseBodyStreamerCallback(closure: closure))
    }
}

extension HBResponseBody: CustomStringConvertible {
    public var description: String {
        let maxOutput = 256
        switch self {
        case .empty:
            return "empty"

        case .byteBuffer(let buffer):
            var buffer2 = buffer
            if let string = buffer2.readString(length: min(maxOutput, buffer2.readableBytes)),
               string.allSatisfy(\.isASCII)
            {
                if buffer2.readableBytes > 0 {
                    return "\"\(string)...\""
                } else {
                    return "\"\(string)\""
                }
            } else {
                return "\(buffer.readableBytes) bytes"
            }

        case .stream:
            return "byte stream"
        }
    }
}

/// Object supplying ByteBuffers for a response body
public protocol HBResponseBodyStreamer: HBSendable {
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput>
}

extension HBResponseBodyStreamer {
    /// Call closure for every ByteBuffer streamed
    /// - Returns: When everything has been streamed
    func write(on eventLoop: EventLoop, _ writeCallback: @escaping (ByteBuffer) -> Void) -> EventLoopFuture<Void> {
        let promise = eventLoop.makePromise(of: Void.self)
        func _stream() {
            self.read(on: eventLoop).whenComplete { result in
                switch result {
                case .success(.byteBuffer(let buffer)):
                    writeCallback(buffer)
                    _stream()
                case .success(.end):
                    promise.succeed(())
                case .failure(let error):
                    promise.fail(error)
                }
            }
        }
        _stream()
        return promise.futureResult
    }
}

/// Response body that you can feed ByteBuffers
struct ResponseByteBufferStreamer: HBResponseBodyStreamer {
    let streamer: HBStreamerProtocol

    /// Read ByteBuffer from streamer.
    ///
    /// This is used internally when serializing the response body
    /// - Parameter eventLoop: EventLoop everything runs on
    /// - Returns: Streamer output (ByteBuffer or end of stream)
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        return self.streamer.consume(on: eventLoop)
    }
}

struct ResponseBodyStreamerCallback: HBResponseBodyStreamer {
    /// Closure called whenever a new ByteBuffer is needed
    let closure: HBStreamCallback

    /// Read ByteBuffer from streamer.
    ///
    /// This is used internally when serializing the response body
    /// - Parameter eventLoop: EventLoop everything runs on
    /// - Returns: Streamer output (ByteBuffer or end of stream)
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        return self.closure(eventLoop)
    }
}
