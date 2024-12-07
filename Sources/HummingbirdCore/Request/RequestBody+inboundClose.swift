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
    /// This function is designed for use with long running requests like server sent events. It comes
    /// with a number of limitations.
    /// - `withInboundCloseHandler` will consume the request body so it will not be available after
    ///     this function has been called.
    /// - If the response finishes the connection will be closed.
    ///
    /// - Parameter process: closure to run
    /// - Returns: Return value of closure
    @available(macOS 15, iOS 18, tvOS 18, *)
    public func consumeWithInboundCloseHandler<Value: Sendable>(
        _ operation: sending (RequestBody) async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        let iterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>? =
            switch self._backing {
            case .nioAsyncChannelRequestBody(let iterator):
                iterator.underlyingIterator
            default:
                nil
            }
        let (requestBody, source) = RequestBody.makeStream()
        return try await withInboundCloseHandler(
            iterator: iterator?.wrappedValue,
            source: source,
            operation: {
                try await operation(requestBody)
            },
            onInboundClosed: onInboundClosed
        )
    }

    fileprivate enum CancelOnInboundGroupType<Value: Sendable>: Sendable {
        case value(Value)
        case inboundClosed
    }

    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// For `cancelOnInboundClose` to work you need to enable it in the HTTP channel configuration
    /// using ``HTTP1Channel/Configuration/supportCancelOnInboundClosure``.
    ///
    /// - Parameter process: closure to run
    /// - Returns: Return value of closure
    public func consumeWithCancelOnInboundClose<Value: Sendable>(
        _ operation: sending @escaping (RequestBody) async throws -> Value
    ) async throws -> Value {
        let (barrier, source) = AsyncStream<Void>.makeStream()
        return try await consumeWithInboundCloseHandler { body in
            let unsafeOperation = UnsafeTransfer(operation)
            return try await withThrowingTaskGroup(of: CancelOnInboundGroupType<Value>.self) { group in
                group.addTask {
                    guard await barrier.first(where: { _ in true }) != nil else {
                        throw CancellationError()
                    }
                    return .inboundClosed
                }
                group.addTask {
                    do {
                        return try await .value(unsafeOperation.wrappedValue(body))
                    } catch {
                        throw error
                    }
                }
                if case .value(let value) = try await group.next() {
                    source.finish()
                    return value
                }
                group.cancelAll()
                throw CancellationError()
            }
        } onInboundClosed: {
            source.yield()
        }
    }

    @available(macOS 15, iOS 18, tvOS 18, *)
    func withInboundCloseHandler<Value: Sendable>(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?,
        source: RequestBody.Source,
        operation: sending () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        guard let iterator else { return try await operation() }
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

    enum IterateResult {
        case inboundClosed
        case nextRequestReady
    }

    @available(macOS 15, iOS 18, tvOS 18, *)
    func iterate(
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
