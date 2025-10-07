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

public import HTTPTypes
import NIOCore

/// Default HTTP error. Provides an HTTP status and a message
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

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        if let body {
            let codable = CodableFormat(error: CodableFormat.ErrorFormat(message: body))
            var response = try context.responseEncoder.encode(codable, from: request, context: context)

            response.status = self.status
            response.headers.append(contentsOf: self.headers)

            return response
        } else {
            return Response(status: self.status, headers: self.headers)
        }
    }
}

extension HTTPError: CustomStringConvertible {
    /// Description of error for logging
    public var description: String {
        let status = self.status.reasonPhrase
        return "HTTPError: \(status)\(self.body.map { ", \($0)" } ?? "")"
    }
}
