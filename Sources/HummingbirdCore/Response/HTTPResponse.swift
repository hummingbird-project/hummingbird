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

/// HTTP response
public struct HBHTTPResponse: Sendable {
    public var head: HTTPResponse
    public var body: HBResponseBody

    public init(head: HTTPResponse, body: HBResponseBody = .init()) {
        self.head = head
        self.body = body
        if let contentLength = body.contentLength {
            self.head.headerFields[.contentLength] = String(describing: contentLength)
        }
    }

    public init(status: HTTPResponse.Status, headers: HTTPFields = .init(), body: HBResponseBody = .init()) {
        self.head = .init(status: status, headerFields: headers)
        self.body = body
        if let contentLength = body.contentLength {
            self.head.headerFields[.contentLength] = String(describing: contentLength)
        }
    }

    var status: HTTPResponse.Status {
        get { self.head.status }
        set { self.head.status = newValue }
    }

    var headers: HTTPFields {
        get { self.head.headerFields }
        set { self.head.headerFields = newValue }
    }
}

extension HBHTTPResponse: CustomStringConvertible {
    public var description: String {
        "Status: \(self.status), headers: \(self.headers), body: \(self.body)"
    }
}
