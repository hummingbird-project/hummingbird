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

import Dispatch
import Metrics

/// Middleware recording metrics for each request
///
/// Records the number of requests, the request duration and how many errors were thrown. Each metric has additional
/// dimensions URI and method.
///
/// Uses [Swift-Metrics](https://github.com/apple/swift-metrics) for recording the metrics.
/// Swift-Metrics has a flexible backend, which will need to be initialized before any metrics are recorded.
///
/// A list of implementations is available in the swift-log repository's README.
public struct MetricsMiddleware<Context: RequestContext>: RouterMiddleware {
    public init() {}

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let startTime = DispatchTime.now().uptimeNanoseconds
        let activeRequestMeter = Meter(label: "http.server.active_requests", dimensions: [("http.request.method", request.method.description)])
        activeRequestMeter.increment()
        do {
            var response = try await next(request, context)
            let responseStatus = response.status
            response.body = response.body.withPostWriteClosure {
                // need to create dimensions once request has been responded to ensure
                // we have the correct endpoint path
                let dimensions: [(String, String)] = [
                    ("http.route", context.endpointPath ?? request.uri.path),
                    ("http.request.method", request.method.rawValue),
                    ("http.response.status_code", responseStatus.code.description),
                ]
                Counter(label: "hb.requests", dimensions: dimensions).increment()
                Metrics.Timer(
                    label: "http.server.request.duration",
                    dimensions: dimensions,
                    preferredDisplayUnit: .seconds
                ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
                activeRequestMeter.decrement()
            }
            return response
        } catch {
            let errorType: String
            if let httpError = error as? any HTTPResponseError {
                errorType = httpError.status.code.description
            } else {
                errorType = "500"
            }
            let endpointPath = context.endpointPath ?? "NotFound"
            // increment requests
            Counter(
                label: "hb.requests",
                dimensions: [
                    ("http.route", endpointPath),
                    ("http.request.method", request.method.rawValue),
                    ("http.response.status_code", errorType),
                ]
            ).increment()
            // increment errors
            Counter(
                label: "hb.request.errors",
                dimensions: [
                    ("http.route", endpointPath),
                    ("http.request.method", request.method.rawValue),
                    ("error.type", errorType),
                ]
            ).increment()
            activeRequestMeter.decrement()
            throw error
        }
    }
}
