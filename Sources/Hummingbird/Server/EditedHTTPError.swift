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
import HummingbirdCore

/// Error generated from another error that adds additional headers to the response
struct EditedHTTPError: HTTPResponseError {
    let status: HTTPResponse.Status
    let headers: HTTPFields
    let body: ByteBuffer?

    init(originalError: Error, additionalHeaders: HTTPFields, context: some RequestContext) {
        if let httpError = originalError as? HTTPResponseError {
            self.status = httpError.status
            self.headers = httpError.headers + additionalHeaders
            self.body = httpError.body(allocator: context.allocator)
        } else {
            self.status = .internalServerError
            self.headers = additionalHeaders
            self.body = nil
        }
    }

    func body(allocator: NIOCore.ByteBufferAllocator) -> NIOCore.ByteBuffer? {
        return self.body
    }
}
