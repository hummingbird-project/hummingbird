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
public struct HBMetricsMiddleware<Context: HBBaseRequestContext>: HBMiddlewareProtocol {
    public init() {}

    public func handle(_ request: HBRequest, context: Context, next: (HBRequest, Context) async throws -> HBResponse) async throws -> HBResponse {
        let startTime = DispatchTime.now().uptimeNanoseconds

        do {
            let response = try await next(request, context)
            // need to create dimensions once request has been responded to ensure
            // we have the correct endpoint path
            let dimensions: [(String, String)] = [
                ("hb_uri", context.endpointPath ?? request.uri.path),
                ("hb_method", request.method.rawValue),
            ]
            Counter(label: "hb_requests", dimensions: dimensions).increment()
            Metrics.Timer(
                label: "hb_request_duration",
                dimensions: dimensions,
                preferredDisplayUnit: .seconds
            ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
            return response
        } catch {
            // need to create dimensions once request has been responded to ensure
            // we have the correct endpoint path
            let dimensions: [(String, String)]
            // Don't record uri in 404 errors, to avoid spamming of metrics
            if let endpointPath = context.endpointPath {
                dimensions = [
                    ("hb_uri", endpointPath),
                    ("hb_method", request.method.rawValue),
                ]
                Counter(label: "hb_requests", dimensions: dimensions).increment()
            } else {
                dimensions = [
                    ("hb_method", request.method.rawValue),
                ]
            }
            Counter(label: "hb_errors", dimensions: dimensions).increment()
            throw error
        }
    }
}
