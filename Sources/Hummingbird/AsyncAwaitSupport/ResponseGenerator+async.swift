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
#if compiler(>=5.5.2) && canImport(_Concurrency)
import HummingbirdCore

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class AsyncSequenceResponseBodyStreamer<ByteBufferSequence: AsyncSequence>: HBResponseBodyStreamer where ByteBufferSequence.Element == ByteBuffer {
    var iterator: ByteBufferSequence.AsyncIterator

    init(_ asyncSequence: ByteBufferSequence) {
        self.iterator = asyncSequence.makeAsyncIterator()
    }

    func read(on eventLoop: EventLoop) -> EventLoopFuture<HBStreamerOutput> {
        let promise = eventLoop.makePromise(of: HBStreamerOutput.self)
        promise.completeWithTask {
            if let buffer = try await self.iterator.next() {
                return .byteBuffer(buffer)
            } else {
                return .end
            }
        }
        return promise.futureResult
    }
}

/// Extend AsyncThrowingStream to conform to `HBResponseGenerator` so it can be returned
/// from a route
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncThrowingStream: HBResponseGenerator where Element == ByteBuffer {
    /// Return self as the response
    public func response(from request: HBRequest) -> HBResponse {
        return .init(status: .ok, body: .stream(AsyncSequenceResponseBodyStreamer(self)))
    }
}

/// Extend AsyncStream to conform to `HBResponseGenerator` so it can be returned from
/// a route
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncStream: HBResponseGenerator where Element == ByteBuffer {
    /// Return self as the response
    public func response(from request: HBRequest) -> HBResponse {
        return .init(status: .ok, body: .stream(AsyncSequenceResponseBodyStreamer(self)))
    }
}

/// Wrapper object for AsyncSequence that conforms to `HBResponseGenerator`
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncSequenceResponseGenerator<ByteBufferSequence: AsyncSequence>: HBResponseGenerator where ByteBufferSequence.Element == ByteBuffer {
    let asyncSequence: ByteBufferSequence

    /// Return self as the response
    public func response(from request: HBRequest) -> HBResponse {
        return .init(status: .ok, body: .stream(AsyncSequenceResponseBodyStreamer(self.asyncSequence)))
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension AsyncSequence where Element == ByteBuffer {
    /// Return type that conforms to `HBResponseGenerator` that will serialize contents of sequence
    ///
    /// Preferably I would like to conform `AsyncSequence` to `HBResponseGenerator` but it is not
    /// possible to add conformances to protocols in extensions. So the solution is to return
    /// another object which wraps the `AsyncSequence`
    public var responseGenerator: AsyncSequenceResponseGenerator<Self> { .init(asyncSequence: self) }
}

#if compiler(>=5.6)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
// can guarantee Sendable because the read function is only ever called on the same EventLoop
extension AsyncSequenceResponseBodyStreamer: @unchecked Sendable {}
#endif // compiler(>=5.6)
#endif // compiler(>=5.5.2) && canImport(_Concurrency)
