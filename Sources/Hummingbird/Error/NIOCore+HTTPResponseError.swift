//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
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

// If we catch a too many bytes error report that as payload too large
extension NIOTooManyBytesError: HTTPResponseError {
    public var status: HTTPResponse.Status { .contentTooLarge }
    public var headers: HTTPFields { [:] }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        Response(status: status)
    }
}
