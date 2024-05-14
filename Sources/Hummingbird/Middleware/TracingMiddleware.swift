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
import NIOCore
import Tracing

/// ``RouterMiddleware`` creating Distributed Tracing spans for each request.
///
/// Creates a ``Span`` for each request, including attributes such as the HTTP method.
///
/// You may opt in to recording a specific subset of HTTP request/response header values by passing
/// a set of header names.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct TracingMiddleware<Context: BaseRequestContext>: RouterMiddleware {
    private let headerNamesToRecord: Set<RecordingHeader>
    private let attributes: SpanAttributes?

    /// Intialize a new TracingMiddleware.
    ///
    /// - Parameters
    ///     - recordingHeaders: A list of HTTP header names to be recorded as span attributes. By default, no headers
    ///         are being recorded.
    ///     - attributes: A list of static attributes added to every span. These could be the "net.host.name",
    ///         "net.host.port" or "http.scheme"
    public init(recordingHeaders headerNamesToRecord: some Collection<HTTPField.Name> = [], attributes: SpanAttributes? = nil) {
        self.headerNamesToRecord = Set(headerNamesToRecord.map(RecordingHeader.init))
        self.attributes = attributes
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &serviceContext, using: HTTPHeadersExtractor())

        let operationName: String = {
            guard let endpointPath = context.endpointPath else {
                return "HTTP \(request.method.rawValue) route not found"
            }
            return endpointPath
        }()

        let span = InstrumentationSystem.tracer.startSpan(operationName, context: serviceContext, ofKind: .server)
        span.updateAttributes { attributes in
            if let staticAttributes = self.attributes {
                attributes.merge(staticAttributes)
            }
            attributes["http.method"] = request.method.rawValue
            attributes["http.target"] = request.uri.path
            // TODO: Get HTTP version and scheme
            // attributes["http.flavor"] = "\(request.version.major).\(request.version.minor)"
            // attributes["http.scheme"] = request.uri.scheme?.rawValue
            attributes["http.user_agent"] = request.headers[.userAgent]
            attributes["http.request_content_length"] = request.headers[.contentLength].map { Int($0) } ?? nil

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
                span.updateAttributes { attributes in
                    attributes = self.recordHeaders(response.headers, toSpanAttributes: attributes, withPrefix: "http.response.header.")

                    attributes["http.status_code"] = Int(response.status.code)
                    attributes["http.response_content_length"] = response.body.contentLength
                }
                let spanWrapper = UnsafeTransfer(SpanWrapper(span))
                response.body = response.body.withPostWriteClosure {
                    spanWrapper.wrappedValue.end()
                }
                return response
            }
        } catch {
            let statusCode = (error as? HTTPResponseError)?.status.code ?? 500
            span.attributes["http.status_code"] = statusCode
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

/// ``UnsafeTransfer`` can be used to make non-``Sendable`` values ``Sendable``.
/// As the name implies, the usage of this is unsafe because it disables the sendable checking of the compiler.
/// It can be used similar to `@unsafe Sendable` but for values instead of types.
@usableFromInline
struct UnsafeTransfer<Wrapped> {
    @usableFromInline
    var wrappedValue: Wrapped

    @inlinable
    init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }
}

extension UnsafeTransfer: @unchecked Sendable {}

/// Protocol for request context that stores the remote address of connected client.
///
/// If you want the TracingMiddleware to record the remote address of requests
/// then your request context will need to conform to this protocol
public protocol RemoteAddressRequestContext: BaseRequestContext {
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

extension Span {
    /// Update ``Span`` attributes in a block instead of individually
    ///
    /// Updating a span attribute will involve some type of thread synchronisation
    /// primitive to avoid multiple threads updating the attributes at the same
    /// time. If you update each attributes individually this could cause slowdown.
    /// This function updates the attributes in one call to avoid hitting the
    /// thread synchronisation code multiple times
    ///
    /// - Parameter update: closure used to update span attributes
    func updateAttributes(_ update: (inout SpanAttributes) -> Void) {
        var attributes = self.attributes
        update(&attributes)
        self.attributes = attributes
    }
}
