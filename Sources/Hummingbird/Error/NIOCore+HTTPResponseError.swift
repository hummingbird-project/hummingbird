//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes
public import NIOCore

// If we catch a too many bytes error report that as payload too large
extension NIOTooManyBytesError: HTTPResponseError {
    public var status: HTTPResponse.Status { .contentTooLarge }
    public var headers: HTTPFields { [:] }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        Response(status: self.status)
    }
}
