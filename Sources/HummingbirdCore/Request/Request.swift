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
    public var method: HTTPRequest.Method { self.head.method }
    /// Request HTTP headers
    public var headers: HTTPFields { self.head.headerFields }

    // MARK: Initialization

    /// Create new Request
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - id: Unique RequestID
    public init(
        head: HTTPRequest,
        body: RequestBody
    ) {
        self.uri = .init(head.path ?? "")
        self.head = head
        self.body = body
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
