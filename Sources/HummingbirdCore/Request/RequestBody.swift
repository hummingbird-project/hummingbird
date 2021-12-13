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

/// Request Body. Either a ByteBuffer or a ByteBuffer streamer
public enum HBRequestBody {
    /// Static ByteBuffer
    case byteBuffer(ByteBuffer?)
    /// ByteBuffer streamer
    case stream(HBByteBufferStreamer)

    /// Return as ByteBuffer
    public var buffer: ByteBuffer? {
        switch self {
        case .byteBuffer(let buffer):
            return buffer
        default:
            preconditionFailure("Cannot get buffer on streaming RequestBody")
        }
    }

    /// Return as streamer if it is a streamer
    public var stream: HBStreamerProtocol? {
        switch self {
        case .stream(let streamer):
            return streamer
        case .byteBuffer(let buffer):
            guard let buffer = buffer else {
                return nil
            }
            return HBStaticStreamer(buffer)
        }
    }

    /// Provide body as a single ByteBuffer
    /// - Parameter eventLoop: EventLoop to use
    /// - Returns: EventLoopFuture that will be fulfilled with ByteBuffer. If no body is include then return `nil`
    public func consumeBody(on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer?> {
        switch self {
        case .byteBuffer(let buffer):
            return eventLoop.makeSucceededFuture(buffer)
        case .stream(let streamer):
            return streamer.consumeAll().hop(to: eventLoop)
        }
    }
}

extension HBRequestBody: CustomStringConvertible {
    public var description: String {
        let maxOutput = 256
        switch self {
        case .byteBuffer(let buffer):
            guard var buffer2 = buffer else { return "empty" }
            if let string = buffer2.readString(length: min(maxOutput, buffer2.readableBytes)),
               string.allSatisfy(\.isASCII)  {
                if buffer2.readableBytes > 0 {
                    return "\"\(string)...\""
                } else {
                    return "\"\(string)\""
                }
            } else {
                return "\(buffer!.readableBytes) bytes"
            }

        case .stream(_):
            return "byte stream"
        }
    }
}
