//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift HTTP Server open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift HTTP Server project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift HTTP Server project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public import AsyncStreaming
public import BasicContainers
import ContainersPreview
public import HTTPTypes
package import NIOCore
package import NIOHTTPTypes
import Synchronization

public protocol RequestAsyncReader: AsyncReader, ~Copyable where Buffer == UniqueArray<UInt8>, ReadFailure == any Error, FinalElement == HTTPFields? {
}

public struct BaseRequestAsyncReader: RequestAsyncReader, ~Copyable {
    package final class ReaderState: Sendable {
        struct Wrapped: ~Copyable {
            var finishedReading: Bool = false

            /// The iterator. Initially populated from the channel; taken by the
            /// body reader at construction time and returned by it once request
            /// `.end` has been observed (for HTTP/1.1 keep-alive recovery).
            var iterator:
                Disconnected<
                    NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?
                >
        }

        let wrapped: Mutex<Wrapped>

        package init(iterator: consuming sending NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator) {
            self.wrapped = .init(.init(iterator: Disconnected(value: iterator)))
        }

        /// Takes the iterator out of the state. Returns the iterator if present,
        /// or `nil` if it's already been taken (e.g. by the body reader).
        package func takeIterator() -> sending NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator? {
            self.wrapped.withLock { state in
                state.iterator.swap(newValue: nil)
            }
        }
    }

    public typealias ReadElement = UInt8

    public typealias Buffer = UniqueArray<UInt8>

    public typealias FinalElement = HTTPFields?

    public typealias ReadFailure = any Error

    private var state: ReaderState

    /// The iterator that provides HTTP request parts from the underlying channel.
    /// Taken from `state` at construction; returned to `state` when this reader
    /// observes request `.end` so the outer request loop can recover it for
    /// HTTP/1.1 keep-alive.
    private var iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?

    /// A reusable buffer handed to the body closure on each call to ``read(body:)``.
    /// Reusing it across calls preserves the allocation; the buffer is cleared
    /// (while keeping its capacity) at the start of every read.
    private var buffer: UniqueArray<UInt8>

    /// Initializes a new request body reader, taking the iterator from the
    /// shared `ReaderState`.
    package init(readerState: ReaderState) {
        self.state = readerState
        self.iterator = readerState.takeIterator()
        self.buffer = UniqueArray<UInt8>()
    }

    public mutating func read<Return: ~Copyable, Failure: Error>(
        body: nonisolated(nonsending) (inout Buffer, consuming HTTPFields??) async throws(Failure) -> Return
    ) async throws(EitherError<ReadFailure, Failure>) -> Return {
        let requestPart: HTTPRequestPart?
        do {
            requestPart = try await self.iterator?.next(isolation: #isolation)
        } catch {
            throw .first(error)
        }

        let trailerFields: HTTPFields??
        self.buffer.removeAll(keepingCapacity: true)
        switch requestPart {
        case .head:
            fatalError()
        case .body(let element):
            self.buffer.reserveCapacity(element.readableBytes)
            self.buffer.append(copying: element.readableBytesUInt8Span)
            trailerFields = nil
        case .end(let trailer):
            // Move the iterator back into ReaderState so the outer request
            // loop can recover it for the next request on the same connection
            // (HTTP/1.1 keep-alive).
            nonisolated(unsafe) let iter = self.iterator.take()
            self.state.wrapped.withLock { state in
                state.finishedReading = true
                _ = unsafe state.iterator.swap(newValue: iter)
            }
            trailerFields = trailer
        case .none:
            throw .first(RequestAsyncReaderError.streamEndedBeforeReceivingRequestEnd)
        }

        do {
            return try await body(&self.buffer, trailerFields)
        } catch {
            throw .second(error)
        }
    }
}

@available(*, unavailable)
extension BaseRequestAsyncReader: Sendable {}

// This is a helper type to move a non-Sendable value across isolation regions.
@usableFromInline
struct Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
    // This is safe since we take the value as sending and take consumes it
    // and returns it as sending.
    private nonisolated(unsafe) var value: Value?

    @usableFromInline
    init(value: consuming sending Value) {
        unsafe self.value = .some(value)
    }

    @usableFromInline
    consuming func take() -> sending Value {
        nonisolated(unsafe) let value = unsafe self.value.take()!
        return unsafe value
    }

    @usableFromInline
    mutating func swap(newValue: consuming sending Value) -> sending Value {
        nonisolated(unsafe) let value = unsafe self.value.take()!
        unsafe self.value = consume newValue
        return unsafe value
    }
}

enum RequestAsyncReaderError: Error, CustomStringConvertible {
    case streamEndedBeforeReceivingRequestEnd

    var description: String {
        switch self {
        case .streamEndedBeforeReceivingRequestEnd:
            "The request stream unexpectedly ended before receiving a request end part."
        }
    }
}
