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
        var baggage = request.baggage
        InstrumentationSystem.instrument.extract(request.headers, into: &baggage, using: HTTPHeadersExtractor())

        let operationName: String = {
            guard let endpointPath = request.endpointPath else {
                return "HTTP \(request.method.rawValue) route not found"
            }
            return endpointPath
        }()

        return request.withSpan(operationName, baggage: baggage, ofKind: .server) { request, span in
            span.attributes["http.method"] = request.method.rawValue
            span.attributes["http.target"] = request.uri.path
            span.attributes["http.flavor"] = "\(request.version.major).\(request.version.minor)"
            span.attributes["http.scheme"] = request.uri.scheme?.rawValue
            span.attributes["http.user_agent"] = request.headers.first(name: "user-agent")
            span.attributes["http.request_content_length"] = request.body.buffer?.readableBytes

            span.attributes["net.host.name"] = request.application.server.configuration.address.host
            span.attributes["net.host.port"] = request.application.server.configuration.address.port

            if let remoteAddress = request.remoteAddress {
                span.attributes["net.sock.peer.port"] = remoteAddress.port

                switch remoteAddress.protocol {
                case .inet:
                    span.attributes["net.sock.peer.addr"] = remoteAddress.ipAddress
                case .inet6:
                    span.attributes["net.sock.family"] = "inet6"
                    span.attributes["net.sock.peer.addr"] = remoteAddress.ipAddress
                case .unix:
                    span.attributes["net.sock.family"] = "unix"
                    span.attributes["net.sock.peer.addr"] = remoteAddress.pathname
                default:
                    break
                }
            }

            recordHeaders(request.headers, toSpan: span, withPrefix: "http.request.header.")

            return next.respond(to: request)
                .always { result in
                    switch result {
                    case .success(let response):
                        recordHeaders(response.headers, toSpan: span, withPrefix: "http.response.header.")

                        span.attributes["http.status_code"] = Int(response.status.code)
                        switch response.body {
                        case .byteBuffer(let buffer):
                            span.attributes["http.response_content_length"] = buffer.readableBytes
                        case .stream, .empty:
                            break
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

    func recordHeaders(_ headers: HTTPHeaders, toSpan span: Span, withPrefix prefix: String) {
        for header in self.headerNamesToRecord {
            let values = headers[header.name]
            guard !values.isEmpty else { continue }
            let attribute = "\(prefix)\(header.attributeName)"

            if values.count == 1 {
                span.attributes[attribute] = values[0]
            } else {
                span.attributes[attribute] = values
            }
        }
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
