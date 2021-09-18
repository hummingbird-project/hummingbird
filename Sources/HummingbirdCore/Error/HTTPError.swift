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

/// Default HTTP error. Provides an HTTP status and a message is so desired
public struct HBHTTPError: Error, HBHTTPResponseError {
    /// status code for the error
    public let status: HTTPResponseStatus
    /// any addiitional headers required
    public let headers: HTTPHeaders
    /// error payload, assumed to be a string
    public let body: String?

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    public init(_ status: HTTPResponseStatus) {
        self.status = status
        self.headers = [:]
        self.body = nil
    }

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - message: Associated message
    public init(_ status: HTTPResponseStatus, message: String) {
        self.status = status
        self.headers = ["content-type": "text/plain; charset=utf-8"]
        self.body = message
    }

    /// Get body of error as ByteBuffer
    public func body(allocator: ByteBufferAllocator) -> ByteBuffer? {
        return self.body.map { allocator.buffer(string: $0) }
    }
}

extension HBHTTPError: CustomStringConvertible {
    /// Description of error for logging
    public var description: String {
        let status = self.status.reasonPhrase
        return "HTTPError: \(status)\(self.body.map { ", \($0)" } ?? "")"
    }
}
