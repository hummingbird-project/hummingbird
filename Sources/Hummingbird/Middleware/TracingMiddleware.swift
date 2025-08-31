//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
import NIOCore
import Tracing

/// Middleware creating Distributed Tracing spans for each request.
///
/// Creates a span for each request, including attributes such as the HTTP method.
///
/// You may opt in to recording a specific subset of HTTP request/response header values by passing
/// a set of header names.
///
/// Uses [Swift-Distributed-Tracing](https://github.com/apple/swift-distributed-tracing) for recording the traces.
/// Swift-Distributed-Tracing has a flexible backend, which will need to be initialized before any traces are recorded.
///
/// A list of implementations is available in the swift-distributed-tracing repository's README.
public struct TracingMiddleware<Context: RequestContext>: RouterMiddleware {
    private let headerNamesToRecord: Set<RecordingHeader>
    private let attributes: SpanAttributes?

    /// Intialize a new TracingMiddleware.
    ///
    /// - Parameters
    ///     - recordingHeaders: A list of HTTP header names to be recorded as span attributes. By default, no headers
    ///         are being recorded.
    ///     - parameters: A list of static parameters added to every span. These could be the "net.host.name",
    ///         "net.host.port" or "http.scheme"
    public init(recordingHeaders headerNamesToRecord: some Collection<HTTPField.Name> = [], attributes: SpanAttributes? = nil) {
        self.headerNamesToRecord = Set(headerNamesToRecord.map(RecordingHeader.init))
        self.attributes = attributes
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &serviceContext, using: HTTPHeadersExtractor())

        // span name is updated after route has run
        let operationName = "HTTP \(request.method.rawValue) route not found"

        let span = startSpan(operationName, context: serviceContext, ofKind: .server)
        span.updateAttributes { attributes in
            if let staticAttributes = self.attributes {
                attributes.merge(staticAttributes)
            }
            attributes["http.request.method"] = request.method.rawValue
            attributes["http.target"] = request.uri.path
            // TODO: Get HTTP version and scheme
            // attributes["http.flavor"] = "\(request.version.major).\(request.version.minor)"
            // attributes["http.scheme"] = request.uri.scheme?.rawValue
            attributes["http.user_agent"] = request.headers[.userAgent]
            attributes["http.request.body.size"] = request.headers[.contentLength].map { Int($0) } ?? nil

            if let remoteAddress = (context as? any RemoteAddressRequestContext)?.remoteAddress {
                attributes["net.sock.peer.port"] = remoteAddress.port

                switch remoteAddress.protocol {
                case .inet:
                    attributes["net.sock.peer.addr"] = remoteAddress.ipAddress
                case .inet6:
                    attributes["net.sock.family"] = "inet6"
                    attributes["net.sock.peer.addr"] = remoteAddress.ipAddress
                case .unix:
                    attributes["net.sock.family"] = "unix"
                    attributes["net.sock.peer.addr"] = remoteAddress.pathname
                default:
                    break
                }
            }
            attributes = self.recordHeaders(request.headers, toSpanAttributes: attributes, withPrefix: "http.request.header.")
        }

        do {
            return try await ServiceContext.$current.withValue(span.context) {
                var response = try await next(request, context)
                if let endpointPath = context.endpointPath {
                    span.operationName = endpointPath
                }
                span.updateAttributes { attributes in
                    attributes = self.recordHeaders(response.headers, toSpanAttributes: attributes, withPrefix: "http.response.header.")

                    attributes["http.response.status_code"] = Int(response.status.code)
                    attributes["http.response_content_length"] = response.body.contentLength
                }
                let spanWrapper = UnsafeTransfer(SpanWrapper(span))
                response.body = response.body.withPostWriteClosure {
                    spanWrapper.wrappedValue.end()
                }
                return response
            }
        } catch {
            if let endpointPath = context.endpointPath {
                span.operationName = endpointPath
            }
            let statusCode = (error as? HTTPResponseError)?.status.code ?? 500
            span.attributes["http.response.status_code"] = statusCode
            if 500..<600 ~= statusCode {
                span.setStatus(.init(code: .error))
            }
            span.recordError(error)
            span.end()
            throw error
        }
    }

    func recordHeaders(_ headers: HTTPFields, toSpanAttributes attributes: SpanAttributes, withPrefix prefix: String) -> SpanAttributes {
        var attributes = attributes
        for header in self.headerNamesToRecord {
            let values = headers[values: header.name]
            guard !values.isEmpty else { continue }
            let attribute = "\(prefix)\(header.attributeName)"

            if values.count == 1 {
                attributes[attribute] = values[0]
            } else {
                attributes[attribute] = values
            }
        }
        return attributes
    }
}

/// Stores a reference to a span and on release ends the span
private class SpanWrapper {
    var span: (any Span)?

    init(_ span: any Span) {
        self.span = span
    }

    func end() {
        self.span?.end()
        self.span = nil
    }

    deinit {
        self.span?.end()
    }
}

/// Protocol for request context that stores the remote address of connected client.
///
/// If you want the TracingMiddleware to record the remote address of requests
/// then your request context will need to conform to this protocol
public protocol RemoteAddressRequestContext: RequestContext {
    /// Connected host address
    var remoteAddress: SocketAddress? { get }
}

struct RecordingHeader: Hashable {
    let name: HTTPField.Name
    let attributeName: String

    init(name: HTTPField.Name) {
        self.name = name
        self.attributeName = name.canonicalName.replacingOccurrences(of: "-", with: "_")
    }
}

private struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPFields) -> String? {
        guard let headerName = HTTPField.Name(name) else { return nil }
        return headers[headerName]
    }
}
