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
public struct HBRequest: Sendable {
    // MARK: Member variables

    /// URI path
    public let uri: HBURI
    /// HTTP head
    public let head: HTTPRequest
    /// Body of HTTP request
    public var body: HBRequestBody
    /// Request HTTP method
    public var method: HTTPRequest.Method { self.head.method }
    /// Request HTTP headers
    public var headers: HTTPFields { self.head.headerFields }

    // MARK: Initialization

    /// Create new HBRequest
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - id: Unique RequestID
    public init(
        head: HTTPRequest,
        body: HBRequestBody
    ) {
        self.uri = .init(head.path ?? "")
        self.head = head
        self.body = body
    }
}

extension HBRequest: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
