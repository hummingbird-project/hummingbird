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
import HummingbirdRouter
import NIOCore
import Tracing

/// Middleware creating Distributed Tracing spans for each request.
///
/// Creates a span for each request, including attributes such as the HTTP method.
///
/// You may opt in to recording a specific subset of HTTP request/response header values by passing
/// a set of header names to ``init(recordingHeaders:)``.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct HBTracingMiddleware<Context: HBRequestContext>: HBMiddleware {
    private let headerNamesToRecord: Set<RecordingHeader>

    /// Intialize a new HBTracingMiddleware.
    ///
    /// - Parameter recordingHeaders: A list of HTTP header names to be recorded as span attributes. By default, no headers
    /// are being recorded.
    public init(recordingHeaders headerNamesToRecord: some Collection<HTTPField.Name>) {
        self.headerNamesToRecord = Set(headerNamesToRecord.map(RecordingHeader.init))
    }

    /// Intialize a new HBTracingMiddleware.
    public init() {
        self.init(recordingHeaders: [])
    }

    public func apply(to request: HBRequest, context: Context, next: any HBResponder<Context>) async throws -> HBResponse {
        var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
        InstrumentationSystem.instrument.extract(request.headers, into: &serviceContext, using: HTTPHeadersExtractor())

        let operationName: String = {
            guard let endpointPath = context.endpointPath else {
                return "HTTP \(request.method.rawValue) route not found"
            }
            return endpointPath
        }()

        return try await InstrumentationSystem.tracer.withSpan(operationName, context: serviceContext, ofKind: .server) { span in
            span.updateAttributes { attributes in
                attributes["http.method"] = request.method.rawValue
                attributes["http.target"] = request.uri.path
                // TODO: Get HTTP version and scheme
                // attributes["http.flavor"] = "\(request.version.major).\(request.version.minor)"
                // attributes["http.scheme"] = request.uri.scheme?.rawValue
                attributes["http.user_agent"] = request.headers[.userAgent]
                attributes["http.request_content_length"] = request.headers[.contentLength].map { Int($0) } ?? nil

                attributes["net.host.name"] = context.applicationContext.configuration.address.host
                attributes["net.host.port"] = context.applicationContext.configuration.address.port

                if let remoteAddress = (context as? HBRemoteAddressRequestContext)?.remoteAddress {
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
                let response = try await next.respond(to: request, context: context)
                span.updateAttributes { attributes in
                    attributes = self.recordHeaders(response.headers, toSpanAttributes: attributes, withPrefix: "http.response.header.")

                    attributes["http.status_code"] = Int(response.status.code)
                    attributes["http.response_content_length"] = response.body.contentLength
                }
                return response
            } catch let error as HBHTTPResponseError {
                span.attributes["http.status_code"] = Int(error.status.code)

                if 500..<600 ~= error.status.code {
                    span.setStatus(.init(code: .error))
                }

                throw error
            }
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

/// Protocol for request context that stores the remote address of connected client.
///
/// If you want the HBTracingMiddleware to record the remote address of requests
/// then your request context will need to conform to this protocol
public protocol HBRemoteAddressRequestContext: HBRequestContext {
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
    /// Update Span attributes in a block instead of individually
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
