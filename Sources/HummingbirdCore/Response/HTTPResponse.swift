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
public struct HBHTTPResponse: Sendable {
    public var status: HTTPResponseStatus
    public var headers: HTTPHeaders
    public var body: HBResponseBody

    public init(status: HTTPResponseStatus, headers: HTTPHeaders = .init(), body: HBResponseBody = .init()) {
        self.status = status
        self.headers = headers
        self.body = body
        if let contentLength = body.contentLength {
            self.headers.replaceOrAdd(name: "content-length", value: String(describing: contentLength))
        }
    }
}

extension HBHTTPResponse: CustomStringConvertible {
    public var description: String {
        "Status: \(self.status), headers: \(self.headers), body: \(self.body)"
    }
}
