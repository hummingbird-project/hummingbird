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

/// Holds all the required to generate a HTTP Response
public struct Response: Sendable {
    public var head: HTTPResponse
    public var body: ResponseBody {
        didSet {
            if let contentLength = body.contentLength {
                self.head.headerFields[.contentLength] = String(describing: contentLength)
            }
        }
    }

    public init(status: HTTPResponse.Status, headers: HTTPFields = .init(), body: ResponseBody = .init()) {
        self.head = .init(status: status, headerFields: headers)
        self.body = body
        if let contentLength = body.contentLength, headers[values: .contentLength].count == 0 {
            self.head.headerFields[.contentLength] = String(describing: contentLength)
        }
    }

    public var status: HTTPResponse.Status {
        get { self.head.status }
        set { self.head.status = newValue }
    }

    public var headers: HTTPFields {
        get { self.head.headerFields }
        set { self.head.headerFields = newValue }
    }

    /// Return HEAD response based off this response
    public func createHeadResponse() -> Response {
        .init(status: self.status, headers: self.headers, body: .init())
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        "status: \(self.status), headers: \(self.headers), body: \(self.body)"
    }
}
