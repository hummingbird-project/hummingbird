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
    @inlinable
    public var head: HTTPResponse {
        get { HTTPResponse(status: status, headerFields: headers) }
        set {
            self.status = newValue.status
            self.headers = newValue.headerFields
        }
    }

    public var body: ResponseBody {
        didSet {
            if let contentLength = body.contentLength {
                self.headers[.contentLength] = String(describing: contentLength)
            }
        }
    }

    public init(status: HTTPResponse.Status, headers: HTTPFields = .init(), body: ResponseBody = .init()) {
        self.status = status
        self.headers = headers
        self.body = body
        if let contentLength = body.contentLength, self.headers[.contentLength] == nil {
            self.headers[.contentLength] = String(describing: contentLength)
        }
    }

    public var status: HTTPResponse.Status
    public var headers: HTTPFields

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
