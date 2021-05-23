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

import Foundation
import NIO
import NIOHTTP1

/// HTTP client types
extension HBXCTClient {
    public enum Error: Swift.Error {
        case invalidURL
        case malformedResponse
        case noResponse
        case tlsSetupFailed
        case readTimeout
    }

    public struct Request {
        public var uri: String
        public var method: HTTPMethod
        public var headers: HTTPHeaders
        public var body: ByteBuffer?

        public init(_ uri: String, method: HTTPMethod, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
            self.uri = uri
            self.method = method
            self.headers = headers
            self.body = body
        }
    }

    public struct Response {
        public let headers: HTTPHeaders
        public let status: HTTPResponseStatus
        public let body: ByteBuffer?
    }
}
