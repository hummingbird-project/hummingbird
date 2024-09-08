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
public struct MetricsMiddleware<Context: RequestContext>: RouterMiddleware {
    public init() {}

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let startTime = DispatchTime.now().uptimeNanoseconds

        do {
            var response = try await next(request, context)
            response.body = response.body.withPostWriteClosure {
                // need to create dimensions once request has been responded to ensure
                // we have the correct endpoint path
                let dimensions: [(String, String)] = [
                    ("http.route", context.endpointPath ?? request.uri.path),
                    ("http.request.method", request.method.rawValue),
                ]
                Counter(label: "hb.requests", dimensions: dimensions).increment()
                Metrics.Timer(
                    label: "http.server.request.duration",
                    dimensions: dimensions,
                    preferredDisplayUnit: .seconds
                ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
            }
            return response
        } catch {
            let errorType: String
            if let httpError = error as? HTTPResponseError {
                errorType = httpError.status.description
            } else {
                errorType = HTTPResponse.Status.internalServerError.description
            }
            // need to create dimensions once request has been responded to ensure
            // we have the correct endpoint path
            let dimensions: [(String, String)]
            // Don't record uri in 404 errors, to avoid spamming of metrics
            if let endpointPath = context.endpointPath {
                dimensions = [
                    ("http.route", endpointPath),
                    ("http.request.method", request.method.rawValue),
                    ("error.type", errorType),
                ]
                Counter(label: "hb.requests", dimensions: dimensions).increment()
            } else {
                dimensions = [
                    ("http.request.method", request.method.rawValue),
                    ("error.type", errorType),
                ]
            }
            Counter(label: "hb.errors", dimensions: dimensions).increment()
            throw error
        }
    }
}
