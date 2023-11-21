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

import NIOHTTP1

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `HBResponse`.
public protocol HBResponseGenerator {
    /// Generate response based on the request this object came from
    func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) throws -> HBResponse
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    /// Return self as the response
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) -> HBResponse {
        let buffer = context.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .init(byteBuffer: buffer))
    }
}

/// Extend String to conform to ResponseGenerator
extension Substring: HBResponseGenerator {
    /// Generate response holding string
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) -> HBResponse {
        let buffer = context.allocator.buffer(substring: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .init(byteBuffer: buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    /// Generate response holding bytebuffer
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) -> HBResponse {
        HBResponse(status: .ok, headers: ["content-type": "application/octet-stream"], body: .init(byteBuffer: self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: HBResponseGenerator {
    /// Generate response with this response status code
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .init())
    }
}

/// Extend Optional to conform to HBResponseGenerator
extension Optional: HBResponseGenerator where Wrapped: HBResponseGenerator {
    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) throws -> HBResponse {
        switch self {
        case .some(let wrapped):
            return try wrapped.response(from: request, context: context)
        case .none:
            return HBResponse(status: .noContent, headers: [:], body: .init())
        }
    }
}

public struct HBEditedResponse<Generator: HBResponseGenerator>: HBResponseGenerator {
    public var status: HTTPResponseStatus?
    public var headers: HTTPHeaders
    public var responseGenerator: Generator

    public init(
        status: HTTPResponseStatus? = nil,
        headers: HTTPHeaders = .init(),
        response: Generator
    ) {
        self.status = status
        self.headers = headers
        self.responseGenerator = response
    }

    public func response<Context: HBBaseRequestContext>(from request: HBRequest, context: Context) throws -> HBResponse {
        var response = try responseGenerator.response(from: request, context: context)
        if let status = self.status {
            response.status = status
        }
        if self.headers.count > 0 {
            // only add headers from generated response if they don't exist in override headers
            var headers = self.headers
            for (name, value) in response.headers {
                if headers[name].first == nil {
                    headers.add(name: name, value: value)
                }
            }
            response.headers = headers
        }
        return response
    }
}
