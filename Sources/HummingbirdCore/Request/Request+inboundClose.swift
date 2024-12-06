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
extension Request {
    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// For `cancelOnInboundClose` to work you need to enable it in the HTTP channel configuration
    /// using ``HTTP1Channel/Configuration/supportCancelOnInboundClosure``.
    ///
    /// - Parameter process: closure to run
    /// - Returns: Return value of closure
    public func cancelOnInboundClose<Value: Sendable>(_ operation: sending @escaping (Request) async throws -> Value) async throws -> Value {
        guard let iterationState = self.iterationState else { return try await operation(self) }
        let iterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>? =
            switch self.body._backing {
            case .nioAsyncChannelRequestBody(let iterator):
                iterator.underlyingIterator
            default:
                nil
            }
        let (stream, source) = RequestBody.makeStream()
        var request = self
        request.body = stream
        let newRequest = request
        return try await iterationState.cancelOnIteratorFinished(iterator: iterator?.wrappedValue, source: source) {
            try await operation(newRequest)
        }
    }

    /// Run provided closure but cancel it if the inbound request part stream is closed.
    ///
    /// For `withInboundCloseHandler` to work you need to enable it in the HTTP channel configuration
    /// using ``HTTP1Channel/Configuration/supportCancelOnInboundClosure``.
    ///
    /// - Parameter process: closure to run
    /// - Returns: Return value of closure
    public func withInboundCloseHandler<Value: Sendable>(
        _ operation: sending @escaping (Request) async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        guard let iterationState = self.iterationState else { return try await operation(self) }
        let iterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>? =
            switch self.body._backing {
            case .nioAsyncChannelRequestBody(let iterator):
                iterator.underlyingIterator
            default:
                nil
            }
        let (stream, source) = RequestBody.makeStream()
        var request = self
        request.body = stream
        let newRequest = request
        return try await iterationState.withInboundCloseHandler(
            iterator: iterator?.wrappedValue,
            source: source,
            operation: {
                try await operation(newRequest)
            },
            onInboundClosed: onInboundClosed
        )
    }
}
#endif  // compiler(>=6.0)

/// Request iteration state
@usableFromInline
package actor RequestIterationState: Sendable {
    fileprivate enum CancelOnInboundGroupType<Value: Sendable> {
        case value(Value)
        case done
    }
    @usableFromInline
    package enum State: Sendable {
        case idle
        case processing
        case nextHead(HTTPRequest)
        case closed
    }
    @usableFromInline
    var state: State

    init() {
        self.state = .idle
    }

    enum IterateResult {
        case inboundClosed
        case nextRequestReady
    }

    #if compiler(>=6.0)
    @available(macOS 15, iOS 18, tvOS 18, *)
    func iterate(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator,
        source: RequestBody.Source
    ) async throws -> IterateResult {
        var iterator = iterator
        while let part = try await iterator.next(isolation: self) {
            switch part {
            case .head(let head):
                self.state = .nextHead(head)
                return .nextRequestReady
            case .body(let buffer):
                try await source.yield(buffer)
            case .end:
                source.finish()
            }
        }
        return .inboundClosed
    }

    @available(macOS 15, iOS 18, tvOS 18, *)
    func cancelOnIteratorFinished<Value: Sendable>(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?,
        source: RequestBody.Source,
        operation: sending @escaping () async throws -> Value
    ) async throws -> Value {
        switch (self.state, iterator) {
        case (.idle, .some(let asyncIterator)):
            self.state = .processing
            let unsafeIterator = UnsafeTransfer(asyncIterator)
            let unsafeOperation = UnsafeTransfer(operation)
            return try await withThrowingTaskGroup(of: CancelOnInboundGroupType<Value>.self) { group in
                group.addTask {
                    guard try await self.iterate(iterator: unsafeIterator.wrappedValue, source: source) == .nextRequestReady else {
                        throw CancellationError()
                    }
                    return .done
                }
                group.addTask {
                    try await .value(unsafeOperation.wrappedValue())
                }
                do {
                    while let result = try await group.next() {
                        if case .value(let value) = result {
                            return value
                        }
                    }
                } catch {
                    self.state = .closed
                    throw error
                }
                preconditionFailure("Cannot reach here")
            }
        case (.idle, .none), (.processing, _), (.nextHead, _):
            return try await operation()

        case (.closed, _):
            throw CancellationError()
        }
    }

    @available(macOS 15, iOS 18, tvOS 18, *)
    func withInboundCloseHandler<Value: Sendable>(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?,
        source: RequestBody.Source,
        operation: sending @escaping () async throws -> Value,
        onInboundClosed: @Sendable @escaping () -> Void
    ) async throws -> Value {
        switch (self.state, iterator) {
        case (.idle, .some(let asyncIterator)):
            self.state = .processing
            let unsafeIterator = UnsafeTransfer(asyncIterator)
            let unsafeOnInboundClosed = UnsafeTransfer(onInboundClosed)
            return try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    if try await self.iterate(iterator: unsafeIterator.wrappedValue, source: source) == .inboundClosed {
                        unsafeOnInboundClosed.wrappedValue()
                    }
                }
                let value = try await operation()
                group.cancelAll()
                return value
            }
        case (.idle, .none), (.processing, _), (.nextHead, _):
            return try await operation()

        case (.closed, _):
            throw CancellationError()
        }
    }
    #endif  // compiler(>=6.0)
}
