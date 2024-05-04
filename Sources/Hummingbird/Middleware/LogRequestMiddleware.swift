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
        case all(except: [HTTPField.Name] = [])
        case some([HTTPField.Name])
    }

    let logLevel: Logger.Level
    let includeHeaders: HeaderFilter
    let redactHeaders: [HTTPField.Name]

    public init(_ logLevel: Logger.Level, includeHeaders: HeaderFilter = .none, redactHeaders: [HTTPField.Name] = []) {
        self.logLevel = logLevel
        self.includeHeaders = includeHeaders
        // only include headers in the redaction list if we are outputting them
        self.redactHeaders = switch includeHeaders {
        case .all(let except):
            // don't include headers in the except list
            redactHeaders.filter { header in except.first { $0 == header } == nil }
        case .some(let included):
            // only include headers in the included list
            redactHeaders.filter { header in included.first { $0 == header } != nil }
        case .none:
            []
        }
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
        case .all(let except):
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb_uri": .stringConvertible(request.uri),
                    "hb_method": .string(request.method.rawValue),
                    "hb_headers": .stringConvertible(self.allHeaders(headers: request.headers, except: except)),
                ]
            )
        case .some(let filter):
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb_uri": .stringConvertible(request.uri),
                    "hb_method": .string(request.method.rawValue),
                    "hb_headers": .stringConvertible(self.filterHeaders(headers: request.headers, filter: filter)),
                ]
            )
        }
        return try await next(request, context)
    }

    func filterHeaders(headers: HTTPFields, filter: [HTTPField.Name]) -> [String: String] {
        let headers = filter
            .compactMap { entry -> (key: String, value: String)? in
                guard let value = headers[entry] else { return nil }
                if self.redactHeaders.contains(entry) {
                    return (key: entry.canonicalName, value: "***")
                } else {
                    return (key: entry.canonicalName, value: value)
                }
            }
        return .init(headers) { "\($0), \($1)" }
    }

    func allHeaders(headers: HTTPFields, except: [HTTPField.Name]) -> [String: String] {
        let headers = headers
            .compactMap { entry -> (key: String, value: String)? in
                guard except.first(where: { entry.name == $0 }) == nil else { return nil }
                if self.redactHeaders.contains(entry.name) {
                    return (key: entry.name.canonicalName, value: "***")
                } else {
                    return (key: entry.name.canonicalName, value: entry.value)
                }
            }
        return .init(headers) { "\($0), \($1)" }
    }
}
