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

import NIOCore
import NIOHTTP1

/// HTTP response
public struct HBHTTPResponse {
    public var head: HTTPResponseHead
    public var body: HBResponseBody

    public init(head: HTTPResponseHead, body: HBResponseBody) {
        self.head = head
        self.body = body
    }
}

extension HBHTTPResponse: CustomStringConvertible {
    public var description: String {
        "Head: \(self.head), body: \(self.body)"
    }
}
