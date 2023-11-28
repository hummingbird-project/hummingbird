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

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `HBResponse`.
public protocol HBResponseGenerator {
    /// Generate response based on the request this object came from
    func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    /// Return self as the response
    public func response(from request: HBRequest, context: some HBBaseRequestContext) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest, context: some HBBaseRequestContext) -> HBResponse {
        let buffer = context.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: [.contentType: "text/plain; charset=utf-8"], body: .init(byteBuffer: buffer))
    }
}

/// Extend String to conform to ResponseGenerator
extension Substring: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest, context: some HBBaseRequestContext) -> HBResponse {
        let buffer = context.allocator.buffer(substring: self)
        return HBResponse(status: .ok, headers: [.contentType: "text/plain; charset=utf-8"], body: .init(byteBuffer: buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    /// Generate response holding bytebuffer
    public func response(from request: HBRequest, context: some HBBaseRequestContext) -> HBResponse {
        HBResponse(status: .ok, headers: [.contentType: "application/octet-stream"], body: .init(byteBuffer: self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponse.Status: HBResponseGenerator {
    /// Generate response with this response status code
    public func response(from request: HBRequest, context: some HBBaseRequestContext) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .init())
    }
}

/// Extend Optional to conform to HBResponseGenerator
extension Optional: HBResponseGenerator where Wrapped: HBResponseGenerator {
    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        switch self {
        case .some(let wrapped):
            return try wrapped.response(from: request, context: context)
        case .none:
            return HBResponse(status: .noContent, headers: [:], body: .init())
        }
    }
}

public struct HBEditedResponse<Generator: HBResponseGenerator>: HBResponseGenerator {
    public var status: HTTPResponse.Status?
    public var headers: HTTPFields
    public var responseGenerator: Generator

    public init(
        status: HTTPResponse.Status? = nil,
        headers: HTTPFields = .init(),
        response: Generator
    ) {
        self.status = status
        self.headers = headers
        self.responseGenerator = response
    }

    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        var response = try responseGenerator.response(from: request, context: context)
        if let status = self.status {
            response.status = status
        }
        if self.headers.count > 0 {
            // only add headers from generated response if they don't exist in override headers
            var headers = self.headers
            for header in response.headers {
                if headers[header.name] == nil {
                    headers.append(header)
                }
            }
            response.headers = headers
        }
        return response
    }
}
