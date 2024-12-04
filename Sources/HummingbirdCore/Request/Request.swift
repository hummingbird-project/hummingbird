//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
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

/// Holds all the values required to process a request
public struct Request: Sendable {
    // MARK: Member variables

    /// URI path
    public let uri: URI
    /// HTTP head
    public let head: HTTPRequest
    /// Body of HTTP request
    public var body: RequestBody
    /// Request HTTP method
    @inlinable
    public var method: HTTPRequest.Method { self.head.method }
    /// Request HTTP headers
    @inlinable
    public var headers: HTTPFields { self.head.headerFields }

    private let iterationState: RequestIterationState?

    // MARK: Initialization

    /// Create new Request
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    public init(
        head: HTTPRequest,
        body: RequestBody
    ) {
        self.uri = .init(head.path ?? "")
        self.head = head
        self.body = body
        self.iterationState = .init()
    }

    /// Collapse body into one ByteBuffer.
    ///
    /// This will store the collated ByteBuffer back into the request so is a mutating method. If
    /// you don't need to store the collated ByteBuffer on the request then use
    /// `request.body.collect(maxSize:)`.
    ///
    /// - Parameter maxSize: Maxiumum size of body to collect
    /// - Returns: Collated body
    public mutating func collectBody(upTo maxSize: Int) async throws -> ByteBuffer {
        let byteBuffer = try await self.body.collect(upTo: maxSize)
        self.body = .init(buffer: byteBuffer)
        return byteBuffer
    }

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
        return try await iterationState.cancelOnIteratorFinished(iterator: iterator, source: source) {
            try await process(newRequest)
        }
    }

    package func getState() -> RequestIterationState.State? {
        self.iterationState?.state.withLockedValue { $0 }
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}

package struct RequestIterationState: Sendable {
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
    let state: NIOLockedValueBox<State>

    init() {
        self.state = .init(.idle)
    }

    func cancelOnIteratorFinished<Value: Sendable>(
        iterator: UnsafeTransfer<NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator>?,
        source: RequestBody.Source,
        process: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let state = self.state.withLockedValue { $0 }
        let unsafeSource = UnsafeTransfer(source)
        switch (state, iterator) {
        case (.idle, .some(let asyncIterator)):
            self.state.withLockedValue { $0 = .processing }
            return try await withThrowingTaskGroup(of: CancelOnInboundGroupType<Value>.self) { group in
                group.addTask {
                    var asyncIterator = asyncIterator.wrappedValue
                    let source = unsafeSource.wrappedValue
                    while let part = try await asyncIterator.next() {
                        switch part {
                        case .head(let head):
                            self.state.withLockedValue { $0 = .nextHead(head) }
                            return .done
                        case .body(let buffer):
                            try await source.yield(buffer)
                        case .end:
                            source.finish()
                        }
                    }
                    throw CancellationError()
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
                    self.state.withLockedValue { $0 = .closed }
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
}
