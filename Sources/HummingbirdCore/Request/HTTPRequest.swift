//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOCore

/// HTTP request
public struct HBHTTPRequest: Sendable {
    public var head: HTTPRequest
    public var body: HBRequestBody

    public init(head: HTTPRequest, body: HBRequestBody) {
        self.head = head
        self.body = body
    }

    public var headers: HTTPFields { self.head.headerFields }
}

extension HBHTTPRequest: CustomStringConvertible {
    public var description: String {
        "Head: \(self.head), body: \(self.body)"
    }
}
