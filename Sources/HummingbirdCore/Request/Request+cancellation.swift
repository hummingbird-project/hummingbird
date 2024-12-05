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
    public func cancelOnInboundClose<Value: Sendable>(_ process: @escaping @Sendable (Request) async throws -> Value) async throws -> Value {
        guard let iterationState = self.iterationState else { return try await process(self) }
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
            try await process(newRequest)
        }
    }
}
#endif  // compiler(>=6.0)

package actor RequestIterationState: Sendable {
    fileprivate enum CancelOnInboundGroupType<Value: Sendable> {
        case value(Value)
        case done
    }
    package enum State: Sendable {
        case idle
        case processing
        case nextHead(HTTPRequest)
        case closed
    }
    var state: State

    init() {
        self.state = .idle
    }

    #if compiler(>=6.0)
    @available(macOS 15, iOS 18, tvOS 18, *)
    func iterate(
        iterator: sending NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator,
        source: RequestBody.Source
    ) async throws {
        var iterator = iterator
        while let part = try await iterator.next(isolation: self) {
            switch part {
            case .head(let head):
                self.state = .nextHead(head)
                return
            case .body(let buffer):
                try await source.yield(buffer)
            case .end:
                source.finish()
            }
        }
        throw CancellationError()
    }

    @available(macOS 15, iOS 18, tvOS 18, *)
    func cancelOnIteratorFinished<Value: Sendable>(
        iterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator?,
        source: RequestBody.Source,
        process: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        switch (self.state, iterator) {
        case (.idle, .some(let asyncIterator)):
            self.state = .processing
            let unsafeIterator = UnsafeTransfer(asyncIterator)
            return try await withThrowingTaskGroup(of: CancelOnInboundGroupType<Value>.self) { group in
                group.addTask {
                    try await self.iterate(iterator: unsafeIterator.wrappedValue, source: source)
                    return .done
                }
                group.addTask {
                    try await .value(process())
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
            return try await process()

        case (.closed, _):
            throw CancellationError()
        }
    }
    #endif  // compiler(>=6.0)
}
