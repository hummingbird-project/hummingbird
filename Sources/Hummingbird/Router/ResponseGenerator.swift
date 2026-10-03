//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import BasicContainers
import HTTPAPIs
public import HTTPTypes
public import HummingbirdCore

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `Response`.
@available(hummingbird 3.0, *)
public protocol ResponseGenerator: _HB_SendableMetatype {
    /// Generate response based on the request this object came from
    func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws
}

@available(hummingbird 3.0, *)
extension Response: ResponseGenerator {
    /// Generate response from Response
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await writer.sendAndFinish(response: self.head, body: self.body)
    }
}

/// Extend String to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension String: ResponseGenerator {
    /// Generate response from string
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        var buffer = UniqueArray(copying: self.utf8)
        try await writer.sendAndFinish(
            .init(
                status: .ok,
                headerFields: .defaultHummingbirdHeaders(
                    contentType: "text/plain; charset=utf-8",
                    contentLength: buffer.count
                )
            ),
            buffer: &buffer
        )
    }
}

/// Extend String to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension Substring: ResponseGenerator {
    /// Generate response from substring
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        var buffer = UniqueArray(copying: self.utf8)
        try await writer.sendAndFinish(
            .init(
                status: .ok,
                headerFields: .defaultHummingbirdHeaders(
                    contentType: "text/plain; charset=utf-8",
                    contentLength: buffer.count
                )
            ),
            buffer: &buffer
        )
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension ByteBuffer: ResponseGenerator {
    /// Generate response from ByteBuffer
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        var buffer = UniqueArray(copying: self.readableBytesUInt8Span)
        try await writer.sendAndFinish(
            .init(
                status: .ok,
                headerFields: .defaultHummingbirdHeaders(
                    contentType: "application/octet-stream",
                    contentLength: buffer.count
                )
            ),
            buffer: &buffer
        )
    }
}

/// Extend HTTPResponse.Status to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension HTTPResponse.Status: ResponseGenerator {
    /// Generate response from ByteBuffer
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await writer.sendAndFinish(.init(status: self))
    }
}

/// Extend Optional to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension Optional: ResponseGenerator where Wrapped: ResponseGenerator {
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        switch self {
        case .some(let wrapped):
            try await wrapped.writeResponse(from: request, writer: writer, context: context)
        case .none:
            try await writer.sendAndFinish(.init(status: .noContent))
        }
    }
}

@available(hummingbird 3.0, *)
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

    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await responseGenerator.writeResponse(
            from: request,
            writer: EditHeadResponseWriter(writer) { response in
                if let status = self.status {
                    response.status = status
                }
                if self.headers.count > 0 {
                    // only add headers from generated response if they don't exist in override headers
                    var headers = self.headers
                    for header in response.headerFields {
                        if !headers.contains(header.name) {
                            headers.append(header)
                        }
                    }
                    response.headerFields = headers
                }
            },
            context: context
        )
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
