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

public import HTTPTypes
public import Logging

/// Middleware outputting to log for every call to server.
///
/// Uses [Swift-Log](https://github.com/apple/swift-log) for logging the output.
/// Swift-Log has a flexible backend, and will output to console by default.
/// You can replace the Logging backend with other implementations.
/// A list of implementations is available in the swift-log repository's README.
public struct LogRequestsMiddleware<Context: RequestContext>: RouterMiddleware {
    /// Header filter
    public struct HeaderFilter: Sendable, ExpressibleByArrayLiteral {
        fileprivate enum _Internal: Sendable {
            case none
            case all(except: [HTTPField.Name])
            case some([HTTPField.Name])
        }

        fileprivate let value: _Internal
        fileprivate init(_ value: _Internal) {
            self.value = value
        }

        /// Don't output any headers
        public static var none: Self { .init(.none) }
        /// Output all headers, except the ones indicated
        public static func all(except: [HTTPField.Name] = []) -> Self { .init(.all(except: except)) }
        /// Output only these headers
        public static func some(_ headers: [HTTPField.Name]) -> Self { .init(.some(headers)) }

        public typealias ArrayLiteralElement = HTTPField.Name

        /// ExpressibleByArrayLiteral requirement
        public init(arrayLiteral elements: ArrayLiteralElement...) {
            self.value = .some(elements)
        }
    }

    let logLevel: Logger.Level
    let includeHeaders: HeaderFilter
    let redactHeaders: [HTTPField.Name]

    public init(_ logLevel: Logger.Level, includeHeaders: HeaderFilter = .none, redactHeaders: [HTTPField.Name] = []) {
        self.logLevel = logLevel
        self.includeHeaders = includeHeaders
        // only include headers in the redaction list if we are outputting them
        self.redactHeaders =
            switch includeHeaders.value {
            case .all(let exceptions):
                // don't include headers in the except list
                redactHeaders.filter { header in !exceptions.contains(header) }
            case .some(let included):
                // only include headers in the included list
                redactHeaders.filter { header in included.contains(header) }
            case .none:
                []
            }
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        switch self.includeHeaders.value {
        case .none:
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb.request.path": .stringConvertible(request.uri),
                    "hb.request.method": .string(request.method.rawValue),
                ]
            )
        case .all(let except):
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb.request.path": .stringConvertible(request.uri),
                    "hb.request.method": .string(request.method.rawValue),
                    "hb.request.headers": .stringConvertible(self.allHeaders(headers: request.headers, except: except)),
                ]
            )
        case .some(let filter):
            context.logger.log(
                level: self.logLevel,
                "Request",
                metadata: [
                    "hb.request.path": .stringConvertible(request.uri),
                    "hb.request.method": .string(request.method.rawValue),
                    "hb.request.headers": .stringConvertible(self.filterHeaders(headers: request.headers, filter: filter)),
                ]
            )
        }
        return try await next(request, context)
    }

    func filterHeaders(headers: HTTPFields, filter: [HTTPField.Name]) -> [String: String] {
        let headers =
            filter
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
        let headers =
            headers
            .compactMap { entry -> (key: String, value: String)? in
                if except.contains(where: { entry.name == $0 }) { return nil }
                if self.redactHeaders.contains(entry.name) {
                    return (key: entry.name.canonicalName, value: "***")
                } else {
                    return (key: entry.name.canonicalName, value: entry.value)
                }
            }
        return .init(headers) { "\($0), \($1)" }
    }
}
