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

/// An error that is capable of generating an HTTP response
///
/// By conforming to `HTTPResponseError` you can control how your error will be presented to
/// the client. Errors not conforming to this will be returned with status internalServerError.
public protocol HTTPResponseError: Error {
    /// status code for the error
    var status: HTTPResponse.Status { get }
    /// any addiitional headers required
    var headers: HTTPFields { get }
    /// return error payload.
    func body(allocator: ByteBufferAllocator) -> ByteBuffer?
}

extension HTTPResponseError {
    /// Generate response from error
    /// - Parameter allocator: Byte buffer allocator used to allocate message body
    /// - Returns: Response
    public func response(allocator: ByteBufferAllocator) -> Response {
        let body: ResponseBody
        if let buffer = self.body(allocator: allocator) {
            body = .init(byteBuffer: buffer)
        } else {
            body = .init()
        }
        return .init(status: status, headers: headers, body: body)
    }
}
