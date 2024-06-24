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
import Foundation
import NIOCore
import NIOFoundationCompat

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

    /// error message
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

    fileprivate struct CodableFormat: Encodable {
        struct ErrorFormat: Encodable {
            let message: String
        }

        let error: ErrorFormat
    }

    /// Get body of error as ByteBuffer
    public func body(from request: Request, context: some RequestContext) throws -> Response? {
        guard let body else {
            return nil
        }

        let codable = CodableFormat(error: .init(message: body))
        return try context.responseEncoder.encode(codable, from: request, context: context)
    }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        if let body {
            let codable = CodableFormat(error: CodableFormat.ErrorFormat(message: body))
            var response = try context.responseEncoder.encode(codable, from: request, context: context)

            response.status = status
            response.headers.append(contentsOf: headers)

            return response
        } else {
            return Response(status: status, headers: headers)
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
