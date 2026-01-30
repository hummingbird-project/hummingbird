//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes

/// Holds all the required to generate a HTTP Response
public struct Response: Sendable {
    /// Response status
    public var status: HTTPResponse.Status
    /// Response headers
    public var headers: HTTPFields
    /// Response head constructed from status and headers
    @inlinable
    public var head: HTTPResponse {
        get { HTTPResponse(status: self.status, headerFields: self.headers) }
        set {
            self.status = newValue.status
            self.headers = newValue.headerFields
        }
    }
    @usableFromInline
    /*private*/ var _body: ResponseBody
    /// Response body
    @inlinable
    public var body: ResponseBody {
        get { _body }
        set {
            if let contentLength = newValue.contentLength, self.body.contentLength != newValue.contentLength {
                self.headers[.contentLength] = String(describing: contentLength)
            }
            self._body = newValue
        }
    }

    /// Initialize Response
    @inlinable
    public init(status: HTTPResponse.Status, headers: HTTPFields = .init(), body: ResponseBody = .init()) {
        self.status = status
        self.headers = headers
        self._body = body
        if let contentLength = body.contentLength, !self.headers.contains(.contentLength) {
            self.headers[.contentLength] = String(describing: contentLength)
        }
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
