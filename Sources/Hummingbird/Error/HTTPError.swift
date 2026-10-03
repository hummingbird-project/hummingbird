//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPAPIs
public import HTTPTypes
import HummingbirdCore
import NIOCore

/// Default HTTP error. Provides an HTTP status and a message
@available(hummingbird 3.0, *)
public struct HTTPError: Error, HTTPResponseError, Sendable {
    /// status code for the error
    public var status: HTTPResponse.Status
    /// response headers
    public var headers: HTTPFields

    /// error message
    public var body: String?

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    public init(_ status: HTTPResponse.Status) {
        self.status = status
        self.headers = [:]
        self.body = nil
    }

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - message: Associated message
    public init(_ status: HTTPResponse.Status, message: String) {
        self.status = status
        self.headers = [:]
        self.body = message
    }

    /// Initialize HTTPError
    /// - Parameters:
    ///   - status: HTTP status
    ///   - headers: Headers to include in error
    ///   - message: Optional associated message
    public init(_ status: HTTPResponse.Status, headers: HTTPFields, message: String? = nil) {
        self.status = status
        self.headers = headers
        self.body = message
    }

    fileprivate struct CodableFormat: Encodable {
        struct ErrorFormat: Encodable {
            let message: String
        }

        let error: ErrorFormat
    }

    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        if let body {
            let codable = CodableFormat(error: CodableFormat.ErrorFormat(message: body))
            return try await context.responseEncoder.sendEncoded(
                codable,
                from: request,
                writer: EditHeadResponseWriter(writer) { response in
                    response.status = self.status
                    response.headerFields.append(contentsOf: self.headers)
                },
                context: context
            )
        }
        try await writer.sendAndFinish(.init(status: self.status, headerFields: self.headers))
    }
}

@available(hummingbird 3.0, *)
extension HTTPError: CustomStringConvertible {
    /// Description of error for logging
    public var description: String {
        let status = self.status.reasonPhrase
        return "HTTPError: \(status)\(self.body.map { ", \($0)" } ?? "")"
    }
}
