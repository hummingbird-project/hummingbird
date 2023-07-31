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

import Tracing

/// Middleware creating Distributed Tracing spans for each request.
///
/// Creates a span for each request, including attributes such as the HTTP method.
///
/// You may opt in to recording a specific subset of HTTP request/response header values by passing
/// a set of header names to ``init(recordingHeaders:)``.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct HBTracingMiddleware: HBMiddleware {
    private let headerNamesToRecord: Set<RecordingHeader>

    /// Intialize a new HBTracingMiddleware.
    ///
    /// - Parameter recordingHeaders: A list of HTTP header names to be recorded as span attributes. By default, no headers
    /// are being recorded.
    public init<C: Collection>(recordingHeaders headerNamesToRecord: C) where C.Element == String {
        self.headerNamesToRecord = Set(headerNamesToRecord.map(RecordingHeader.init))
    }

    /// Intialize a new HBTracingMiddleware.
    public init() {
        self.init(recordingHeaders: [])
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        var serviceContext = request.serviceContext
        InstrumentationSystem.instrument.extract(request.headers, into: &serviceContext, using: HTTPHeadersExtractor())

        let operationName: String = {
            guard let endpointPath = request.endpointPath else {
                return "HTTP \(request.method.rawValue) route not found"
            }
            return endpointPath
        }()

        return request.withSpan(operationName, context: serviceContext, ofKind: .server) { request, span in
            span.updateAttributes { attributes in
                attributes["http.method"] = request.method.rawValue
                attributes["http.target"] = request.uri.path
                attributes["http.flavor"] = "\(request.version.major).\(request.version.minor)"
                attributes["http.scheme"] = request.uri.scheme?.rawValue
                attributes["http.user_agent"] = request.headers.first(name: "user-agent")
                attributes["http.request_content_length"] = request.body.buffer?.readableBytes

                attributes["net.host.name"] = request.application.configuration.address.host
                attributes["net.host.port"] = request.application.configuration.address.port

                if let remoteAddress = request.remoteAddress {
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

            return next.respond(to: request)
                .always { result in
                    switch result {
                    case .success(let response):
                        span.updateAttributes { attributes in
                            attributes = self.recordHeaders(response.headers, toSpanAttributes: attributes, withPrefix: "http.response.header.")

                            attributes["http.status_code"] = Int(response.status.code)
                            switch response.body {
                            case .byteBuffer(let buffer):
                                attributes["http.response_content_length"] = buffer.readableBytes
                            case .stream, .empty:
                                break
                            }
                        }
                    case .failure(let error):
                        if let httpError = error as? HBHTTPResponseError {
                            span.attributes["http.status_code"] = Int(httpError.status.code)

                            if 500..<600 ~= httpError.status.code {
                                span.setStatus(.init(code: .error))
                            }
                        }
                    }
                }
        }
    }

    func recordHeaders(_ headers: HTTPHeaders, toSpanAttributes attributes: SpanAttributes, withPrefix prefix: String) -> SpanAttributes {
        var attributes = attributes
        for header in self.headerNamesToRecord {
            let values = headers[header.name]
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

struct RecordingHeader: Hashable {
    let name: String
    let attributeName: String

    init(name: String) {
        self.name = name
        self.attributeName = name.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}

private struct HTTPHeadersExtractor: Extractor {
    func extract(key name: String, from headers: HTTPHeaders) -> String? {
        headers.first(name: name)
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
