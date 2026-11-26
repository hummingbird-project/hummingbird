//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes

@available(hummingbird 2.0, *)
extension RequestBody {
    /// Run provided `operation` closure and run `onInboundClose` closure if the inbound request part stream of
    /// the `RequestBody` is finished.
    ///
    /// This function is designed for use with long running requests like server sent events. It assumes you
    /// are not going to be using the request body after calling as it consumes the request body, it also assumes
    /// you havent edited the request body prior to calling this function..
    ///
    /// - Parameters
    ///   - operation: The actual operation
    ///   - onInboundClose: handler invoked when inbound stream is finished
    /// - Returns: Return value of operation
    #if compiler(<6.3)
    public func withInboundCloseHandler<Value: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        _ operation: () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        switch self._backing {
        case .nioAsyncChannelRequestBody(let body):
            return try await withInboundCloseHandler(
                iterator: body.underlyingIterator.wrappedValue,
                operation: operation,
                onInboundClosed: onInboundClosed
            )

        case .byteBuffer(_, .some(let originalRequestBody)), .anyAsyncSequence(_, .some(let originalRequestBody)):
            let iterator =
                self
                .mergeWithUnderlyingRequestPartIterator(originalRequestBody.underlyingIterator.wrappedValue)
                .makeAsyncIterator()
            return try await withInboundCloseHandler(
                iterator: iterator,
                operation: {
                    try await operation()
                },
                onInboundClosed: onInboundClosed
            )

        default:
            preconditionFailure("Cannot run consumeWithInboundCloseHandler on edited request body")
        }
    }
    #else
    public nonisolated(nonsending) func withInboundCloseHandler<Value: Sendable>(
        _ operation: nonisolated(nonsending) () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        switch self._backing {
        case .nioAsyncChannelRequestBody(let body):
            return try await withInboundCloseHandler(
                iterator: body.underlyingIterator.wrappedValue,
                operation: operation,
                onInboundClosed: onInboundClosed
            )

        case .byteBuffer(_, .some(let originalRequestBody)), .anyAsyncSequence(_, .some(let originalRequestBody)):
            let iterator =
                self
                .mergeWithUnderlyingRequestPartIterator(originalRequestBody.underlyingIterator.wrappedValue)
                .makeAsyncIterator()
            return try await withInboundCloseHandler(
                iterator: iterator,
                operation: {
                    try await operation()
                },
                onInboundClosed: onInboundClosed
            )

        default:
            preconditionFailure("Cannot run consumeWithInboundCloseHandler on edited request body")
        }
    }
    #endif
    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// This function is designed for use with long running requests like server sent events. It assumes you
    /// are not going to be using the request body after calling as it consumes the request body, it also assumes
    /// you havent edited the request body prior to calling this function.
    ///
    /// If the response finishes the connection will be closed.
    ///
    /// - Parameters
    ///   - operation: The actual operation to run
    /// - Returns: Return value of operation
    public func withCancellationOnInboundClose<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        let (barrier, source) = AsyncStream<Void>.makeStream()
        return try await withoutActuallyEscaping(operation) { operation in
            try await withInboundCloseHandler {
                try await withThrowingTaskGroup(of: Value.self) { group in
                    let unsafeOperation = UnsafeTransfer(operation)
                    group.addTask {
                        try await unsafeOperation.wrappedValue()
                    }

                    group.addTask {
                        var iterator = barrier.makeAsyncIterator()
                        _ = await iterator.next()
                        throw CancellationError()
                    }
                    if case .some(let value) = try await group.next() {
                        source.finish()
                        return value
                    }
                    group.cancelAll()
                    throw CancellationError()

                }
            } onInboundClosed: {
                source.finish()
            }
        }
    }

    nonisolated(nonsending) fileprivate func withInboundCloseHandler<Value: Sendable, AsyncIterator: AsyncIteratorProtocol & SendableMetatype>(
        iterator: AsyncIterator,
        operation: nonisolated(nonsending) () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value where AsyncIterator.Element == HTTPRequestPart {
        let unsafeIterator = UnsafeTransfer(iterator)
        let value = try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                if await self.iterate(iterator: unsafeIterator.wrappedValue) == .inboundClosed {
                    onInboundClosed()
                }
            }
            let value = try await operation()
            group.cancelAll()
            return value
        }
        return value
    }

    /// Run provided `operation` closure and runs `onInboundClose`` if the inbound request part stream of
    /// the `RequestBody` is finished.
    ///
    /// This function is designed for use with long running requests like server sent events. Unlike
    /// ``RequestBody/withInboundCloseHandler(_:onInboundClosed:)`` it provides the request body to the
    /// user.
    ///
    /// WARNING: To ensure inbound close events are received you are required to read the contents of request body.
    /// If you do not need the request body use ``RequestBody/withInboundCloseHandler(_:onInboundClosed:)`` instead
    ///
    /// - Parameters
    ///   - isolation: The isolation of the method. Defaults to the isolation of the caller.
    ///   - operation: The actual operation
    ///   - onInboundClose: handler invoked when inbound stream is finished
    /// - Returns: Return value of operation
    public func consumeWithInboundCloseHandler<Value: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        _ operation: (RequestBody) async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        let (requestBody, source) = RequestBody.makeStream()
        switch self._backing {
        case .nioAsyncChannelRequestBody(let body):
            return try await withInboundCloseHandler(
                iterator: body.underlyingIterator.wrappedValue,
                source: source,
                operation: {
                    try await operation(requestBody)
                },
                onInboundClosed: onInboundClosed
            )

        case .byteBuffer(_, .some(let originalRequestBody)), .anyAsyncSequence(_, .some(let originalRequestBody)):
            let iterator =
                self
                .mergeWithUnderlyingRequestPartIterator(originalRequestBody.underlyingIterator.wrappedValue)
                .makeAsyncIterator()
            return try await withInboundCloseHandler(
                iterator: iterator,
                source: source,
                operation: {
                    try await operation(requestBody)
                },
                onInboundClosed: onInboundClosed
            )

        default:
            preconditionFailure("Cannot run consumeWithInboundCloseHandler on edited request body")
        }
    }

    /// Run provided closure but cancel it if the inbound request part stream of the `RequestBody`
    /// is finished.
    ///
    /// This function is designed for use with long running requests like server sent events. Unlike
    /// ``RequestBody/withCancellationOnInboundClose(_:)`` it provides the request body to the user.
    ///
    /// WARNING: To ensure inbound close events are received you are required to read the contents of request body.
    /// If you do not need the request body use ``RequestBody/withCancellationOnInboundClose(_:)`` instead
    ///
    /// If the response finishes the connection will be closed.
    ///
    /// - Parameters
    ///   - operation: The operation to run
    /// - Returns: Return value of operation
    public func consumeWithCancellationOnInboundClose<Value: Sendable>(
        _ operation: (RequestBody) async throws -> Value
    ) async throws -> Value {
        let (barrier, source) = AsyncStream<Void>.makeStream()
        return try await consumeWithInboundCloseHandler { body in
            try await withoutActuallyEscaping(operation) { operation in
                try await withThrowingTaskGroup(of: Value.self) { group in
                    let unsafeOperation = UnsafeTransfer(operation)
                    group.addTask {
                        try await unsafeOperation.wrappedValue(body)
                    }

                    group.addTask {
                        var iterator = barrier.makeAsyncIterator()
                        _ = await iterator.next()
                        throw CancellationError()
                    }
                    if case .some(let value) = try await group.next() {
                        source.finish()
                        return value
                    }
                    group.cancelAll()
                    throw CancellationError()
                }
            }
        } onInboundClosed: {
            source.finish()
        }

    }

    fileprivate func withInboundCloseHandler<Value: Sendable, AsyncIterator: AsyncIteratorProtocol & SendableMetatype>(
        isolation: isolated (any Actor)? = #isolation,
        iterator: AsyncIterator,
        source: RequestBody.Source,
        operation: () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value where AsyncIterator.Element == HTTPRequestPart {
        let unsafeIterator = UnsafeTransfer(iterator)
        let value = try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                if await self.iterate(iterator: unsafeIterator.wrappedValue, source: source) == .inboundClosed {
                    onInboundClosed()
                }
            }
            let value = try await operation()
            group.cancelAll()
            return value
        }
        return value
    }

    fileprivate enum IterateResult {
        case inboundClosed
        case nextRequestReady
    }

    fileprivate func iterate<AsyncIterator: AsyncIteratorProtocol>(
        iterator: AsyncIterator
    ) async -> IterateResult where AsyncIterator.Element == HTTPRequestPart {
        var iterator = iterator
        while true {
            do {
                guard let part = try await iterator.next() else { break }
                switch part {
                case .head:
                    return .nextRequestReady
                case .body, .end:
                    break
                }
            } catch {
                // we received an error on the inbound stream it is in effect closed. This
                // is of particular importance for HTTP2 streams where stream closure invokes
                // an error on the inbound stream of HTTP parts instead of just finishing it.
                return .inboundClosed
            }
        }
        return .inboundClosed
    }

    fileprivate func iterate<AsyncIterator: AsyncIteratorProtocol>(
        iterator: AsyncIterator,
        source: RequestBody.Source
    ) async -> IterateResult where AsyncIterator.Element == HTTPRequestPart {
        var iterator = iterator
        var finished = false
        while true {
            do {
                guard let part = try await iterator.next() else { break }
                switch part {
                case .head:
                    return .nextRequestReady
                case .body(let buffer):
                    try await source.yield(buffer)
                case .end:
                    finished = true
                    source.finish()
                }
            } catch {
                // if we are not finished receiving the request body pass error onto source
                if !finished {
                    source.finish(error)
                }
                // we received an error on the inbound stream it is in effect closed. This
                // is of particular importance for HTTP2 streams where stream closure invokes
                // an error on the inbound stream of HTTP parts instead of just finishing it.
                return .inboundClosed
            }
        }
        return .inboundClosed
    }
}
