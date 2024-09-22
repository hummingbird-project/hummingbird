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

/// HTTP client types
extension TestClient {
    public enum Error: Swift.Error {
        case invalidURL
        case malformedResponse
        case noResponse
        case tlsSetupFailed
        case readTimeout
        case connectionNotOpen
        case connectionClosing
    }

    public struct Request: Sendable {
        public var head: HTTPRequest
        public var body: ByteBuffer?

        public init(_ uri: String, method: HTTPRequest.Method, headers: HTTPFields = [:], body: ByteBuffer? = nil) {
            self.head = .init(method: method, scheme: nil, authority: nil, path: uri, headerFields: headers)
            self.body = body
        }

        public init(_ uri: String, method: HTTPRequest.Method, authority: String?, headers: HTTPFields = [:], body: ByteBuffer? = nil) {
            self.head = .init(method: method, scheme: nil, authority: authority, path: uri, headerFields: headers)
            self.body = body
        }

        var headers: HTTPFields {
            get { self.head.headerFields }
            set { self.head.headerFields = newValue }
        }
    }

    public struct Response: Sendable {
        public var head: HTTPResponse
        public var body: ByteBuffer?
        public var trailerHeaders: HTTPFields?

        public init(head: HTTPResponse, body: ByteBuffer? = nil, trailerHeaders: HTTPFields? = nil) {
            self.head = head
            self.body = body
            self.trailerHeaders = trailerHeaders
        }

        public var status: HTTPResponse.Status {
            get { self.head.status }
            set { self.head.status = newValue }
        }

        public var headers: HTTPFields {
            get { self.head.headerFields }
            set { self.head.headerFields = newValue }
        }
    }
}
