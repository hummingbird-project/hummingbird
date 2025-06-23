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
import HummingbirdCore

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `Response`.
@preconcurrency
public protocol ResponseGenerator: _HB_SendableMetatype {
    /// Generate response based on the request this object came from
    func response(from request: Request, context: some RequestContext) throws -> Response
}

/// Extend Response to conform to ResponseGenerator
extension Response: ResponseGenerator {
    /// Return self as the response
    public func response(from request: Request, context: some RequestContext) -> Response { self }
}

/// Extend String to conform to ResponseGenerator
extension String: ResponseGenerator {
    /// Generate response holding string
    public func response(from request: Request, context: some RequestContext) -> Response {
        let buffer = ByteBuffer(string: self)
        return Response(
            status: .ok,
            headers: .defaultHummingbirdHeaders(
                contentType: "text/plain; charset=utf-8",
                contentLength: buffer.readableBytes
            ),
            body: .init(byteBuffer: buffer)
        )
    }
}

/// Extend String to conform to ResponseGenerator
extension Substring: ResponseGenerator {
    /// Generate response holding string
    public func response(from request: Request, context: some RequestContext) -> Response {
        let buffer = ByteBuffer(substring: self)
        return Response(
            status: .ok,
            headers: .defaultHummingbirdHeaders(
                contentType: "text/plain; charset=utf-8",
                contentLength: buffer.readableBytes
            ),
            body: .init(byteBuffer: buffer)
        )
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: ResponseGenerator {
    /// Generate response holding bytebuffer
    public func response(from request: Request, context: some RequestContext) -> Response {
        Response(
            status: .ok,
            headers: .defaultHummingbirdHeaders(
                contentType: "application/octet-stream",
                contentLength: self.readableBytes
            ),
            body: .init(byteBuffer: self)
        )
    }
}

/// Extend HTTPResponse.Status to conform to ResponseGenerator
extension HTTPResponse.Status: ResponseGenerator {
    /// Generate response with this response status code
    public func response(from request: Request, context: some RequestContext) -> Response {
        Response(status: self, headers: [:], body: .init())
    }
}

/// Extend Optional to conform to ResponseGenerator
extension Optional: ResponseGenerator where Wrapped: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        switch self {
        case .some(let wrapped):
            return try wrapped.response(from: request, context: context)
        case .none:
            return Response(status: .noContent, headers: [:], body: .init())
        }
    }
}

public struct EditedResponse<Generator: ResponseGenerator>: ResponseGenerator {
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

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        var response = try responseGenerator.response(from: request, context: context)
        if let status = self.status {
            response.status = status
        }
        if self.headers.count > 0 {
            // only add headers from generated response if they don't exist in override headers
            var headers = self.headers
            for header in response.headers {
                if !headers.contains(header.name) {
                    headers.append(header)
                }
            }
            response.headers = headers
        }
        return response
    }
}

extension HTTPFields {
    /// Initialize HTTPFields with contentType and contentLength headers and also reserve
    /// space for server and date headers which will be set later
    /// - Parameters:
    ///   - contentType: Content Type header
    ///   - contentLength: Content Length
    @inlinable
    static func defaultHummingbirdHeaders(
        contentType: String,
        contentLength: Int
    ) -> Self {
        var headers = self.init()
        headers.reserveCapacity(4)
        headers.append(.init(name: .contentType, value: contentType))
        headers.append(.init(name: .contentLength, value: contentLength.description))
        return headers
    }
}
