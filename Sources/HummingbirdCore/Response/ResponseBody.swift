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

/// Response body. Either static
public enum HBResponseBody {
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
    public static func streamCallback(_ closure: @escaping (EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>) -> Self {
        .stream(ResponseBodyStreamerCallback(closure: closure))
    }

    /// response body streamer result. Either a ByteBuffer or the end of the stream
    public enum StreamResult {
        case byteBuffer(ByteBuffer)
        case end
    }
}

/// Object supplying bytebuffers for a response body
public protocol HBResponseBodyStreamer {
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>
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

struct ResponseBodyStreamerCallback: HBResponseBodyStreamer {
    let closure: (EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult>
    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBResponseBody.StreamResult> {
        return self.closure(eventLoop)
    }
}
