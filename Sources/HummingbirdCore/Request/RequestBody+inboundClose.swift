//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTPTypes

#if compiler(>=6.0)
@available(macOS 15, iOS 18, tvOS 18, *)
extension RequestBody {
    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// This function is designed for use with long running requests like server sent events. It assumes you
    /// are not going to be using the request body after calling as it consumes the request body, it also assumes
    /// you havent edited the request body prior to calling this function.
    ///
    /// If the response finishes the connection will be closed.
    ///
    /// - Parameters
    ///   - isolation: The isolation of the method. Defaults to the isolation of the caller.
    ///   - operation: The actual operation
    ///   = onInboundClose: handler invoked when inbound is closed
    /// - Returns: Return value of operation
    @available(macOS 15, iOS 18, tvOS 18, *)
    public func consumeWithInboundCloseHandler<Value: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        _ operation: (RequestBody) async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        let iterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator> =
            switch self._backing {
            case .nioAsyncChannelRequestBody(let iterator):
                iterator.underlyingIterator
            default:
                preconditionFailure("Cannot run consumeWithInboundCloseHandler on edited request body")
            }
        let (requestBody, source) = RequestBody.makeStream()
        return try await withInboundCloseHandler(
            iterator: iterator.wrappedValue,
            source: source,
            operation: {
                try await operation(requestBody)
            },
            onInboundClosed: onInboundClosed
        )
    }

    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// This function is designed for use with long running requests like server sent events. It assumes you
    /// are not going to be using the request body after calling as it consumes the request body, it also assumes
    /// you havent edited the request body prior to calling this function.
    ///
    /// If the response finishes the connection will be closed.
    ///
    /// - Parameters
    ///   - isolation: The isolation of the method. Defaults to the isolation of the caller.
    ///   - operation: The actual operation to run
    /// - Returns: Return value of operation
    public func consumeWithCancellationOnInboundClose<Value: Sendable>(
        _ operation: sending @escaping (RequestBody) async throws -> Value
    ) async throws -> Value {
        let (barrier, source) = AsyncStream<Void>.makeStream()
        return try await consumeWithInboundCloseHandler { body in
            try await withThrowingTaskGroup(of: Value.self) { group in
                let unsafeOperation = UnsafeTransfer(operation)
                group.addTask {
                    var iterator = barrier.makeAsyncIterator()
                    _ = await iterator.next()
                    throw CancellationError()
                }
                group.addTask {
                    try await unsafeOperation.wrappedValue(body)
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

    @available(macOS 15, iOS 18, tvOS 18, *)
    fileprivate func withInboundCloseHandler<Value: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator,
        source: RequestBody.Source,
        operation: () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        let unsafeIterator = UnsafeTransfer(iterator)
        let unsafeOnInboundClosed = UnsafeTransfer(onInboundClosed)
        let value = try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    if try await self.iterate(iterator: unsafeIterator.wrappedValue, source: source) == .inboundClosed {
                        unsafeOnInboundClosed.wrappedValue()
                    }
                } catch is CancellationError {}
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

    @available(macOS 15, iOS 18, tvOS 18, *)
    fileprivate func iterate(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator,
        source: RequestBody.Source
    ) async throws -> IterateResult {
        var iterator = iterator
        while let part = try await iterator.next() {
            switch part {
            case .head:
                return .nextRequestReady
            case .body(let buffer):
                try await source.yield(buffer)
            case .end:
                source.finish()
            }
        }
        return .inboundClosed
    }
}
#endif  // compiler(>=6.0)
