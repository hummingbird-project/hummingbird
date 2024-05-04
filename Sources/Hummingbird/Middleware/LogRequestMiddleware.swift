//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import Logging

/// Middleware outputting to log for every call to server
public struct LogRequestsMiddleware<Context: BaseRequestContext>: RouterMiddleware {
    /// Header filter
    public enum HeaderFilter: Sendable, ExpressibleByArrayLiteral {
        public typealias ArrayLiteralElement = HTTPField.Name

        /// ExpressibleByArrayLiteral requirement
        public init(arrayLiteral elements: ArrayLiteralElement...) {
            self = .some(elements)
        }

        case none
        case all
        case some([HTTPField.Name])
    }

    let logLevel: Logger.Level
    let includeHeaders: HeaderFilter

    public init(_ logLevel: Logger.Level, includeHeaders: HeaderFilter = .none) {
        self.logLevel = logLevel
        self.includeHeaders = includeHeaders
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        switch self.includeHeaders {
        case .none:
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb_uri": .stringConvertible(request.uri),
                    "hb_method": .string(request.method.rawValue),
                ]
            )
        case .all:
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb_uri": .stringConvertible(request.uri),
                    "hb_method": .string(request.method.rawValue),
                    "hb_headers": .string(request.headers.logOutput),
                ]
            )
        case .some(let filter):
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb_uri": .stringConvertible(request.uri),
                    "hb_method": .string(request.method.rawValue),
                    "hb_headers": .string(self.filterHeaders(headers: request.headers, filter: filter)),
                ]
            )
        }
        return try await next(request, context)
    }

    func filterHeaders(headers: HTTPFields, filter: [HTTPField.Name]) -> String {
        var filteredHeaders: [(String, String)] = []
        for entry in filter {
            if let value = headers[entry] {
                filteredHeaders.append((entry.canonicalName, value))
            }
        }
        return "{\(filteredHeaders.map { "\"\($0)\":\"\($1)\"" }.joined(separator: ", "))}"
    }
}

extension HTTPFields {
    fileprivate var logOutput: String {
        "{\(self.map { "\"\($0.name.canonicalName)\":\"\($0.value)\"" }.joined(separator: ", "))}"
    }
}
