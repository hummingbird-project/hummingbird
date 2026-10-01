//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import BasicContainers
public import HTTPTypes
import NIOCore

/// Holds all the values required to process a request
public struct Request {
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
    }

    /// Collapse body into a single UniqueArray<UInt8>.
    ///
    /// This will store the collated buffer back into the request so is a mutating method. If
    /// you don't need to store the collated buffer on the request then use
    /// `request.body.collect(maxSize:)`.
    ///
    /// - Parameters
    ///     - maxSize: Maxiumum size of body to collect
    public mutating func collectBody(upTo maxSize: Int, process: (inout UniqueArray<UInt8>) async throws -> Void) async throws {
        var array = try await self.body.collect(upTo: maxSize)
        try await process(&array)
        self.body = .init(.asyncReader(CollatedRequestAsyncReader(array)))
    }
}

@available(hummingbird 3.0, *)
extension Request: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
