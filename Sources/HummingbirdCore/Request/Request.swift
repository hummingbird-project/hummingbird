//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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

    @usableFromInline
    let iterationState: RequestIterationState?

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
        self.iterationState = nil
    }

    /// Create new Request
    /// - Parameters:
    ///   - head: HTTP head
    ///   - bodyIterator: HTTP request part stream
    package init(
        head: HTTPRequest,
        bodyIterator: NIOAsyncChannelInboundStream<HTTPRequestPart>.AsyncIterator,
        supportCancelOnInboundClosure: Bool
    ) {
        self.uri = .init(head.path ?? "")
        self.head = head
        self.body = .init(nioAsyncChannelInbound: .init(iterator: bodyIterator))
        self.iterationState = supportCancelOnInboundClosure ? .init() : nil
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

    @inlinable
    package func getState() async -> RequestIterationState.State? {
        await self.iterationState?.state
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
