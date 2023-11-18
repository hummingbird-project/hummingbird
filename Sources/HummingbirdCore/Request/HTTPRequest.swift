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

/// HTTP request
public struct HBHTTPRequest: Sendable {
    public var head: HTTPRequestHead
    public var body: HBRequestBody

    public init(head: HTTPRequestHead, body: HBRequestBody) {
        self.head = head
        self.body = body
    }
}

extension HBHTTPRequest: CustomStringConvertible {
    public var description: String {
        "Head: \(self.head), body: \(self.body)"
    }
}
