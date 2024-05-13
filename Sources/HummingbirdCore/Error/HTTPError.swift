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

/// Default HTTP error. Provides an HTTP status and a message
public struct HTTPError: Error, HTTPResponseError, Sendable {
    /// status code for the error
    public var status: HTTPResponse.Status
    /// internal representation of error headers without contentType
    private var _headers: HTTPFields
    /// headers
    public var headers: HTTPFields {
        get {
            return self.body != nil ? self._headers + [.contentType: "application/json; charset=utf-8"] : self._headers
        }
        set {
            self._headers = newValue
        }
    }

    /// Error message
    public var body: String?

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    public init(_ status: HTTPResponse.Status) {
        self.status = status
        self._headers = [:]
        self.body = nil
    }

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - message: Associated message
    public init(_ status: HTTPResponse.Status, message: String) {
        self.status = status
        self._headers = [:]
        self.body = message
    }

    /// Get body of error as ByteBuffer
    public func body(allocator: ByteBufferAllocator) -> ByteBuffer? {
        return self.body.map { allocator.buffer(string: "{\"error\":{\"message\":\"\($0)\"}}\n") }
    }
}

extension HTTPError: CustomStringConvertible {
    /// Description of error for logging
    public var description: String {
        let status = self.status.reasonPhrase
        return "HTTPError: \(status)\(self.body.map { ", \($0)" } ?? "")"
    }
}
