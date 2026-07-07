//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Dispatch
import Metrics
import NIOConcurrencyHelpers

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
    let metricsCache: MetricsCache

    public init() {
        self.metricsCache = .init()
    }

    public func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let startTime = DispatchTime.now().uptimeNanoseconds
        let activeRequestMeter = self.metricsCache.getMethodMetrics(id: .init(method: request.method)).activeRequestMeter
        activeRequestMeter.increment()
        do {
            var response = try await next(request, context)
            let responseStatus = response.status
            response.body = response.body.withPostWriteClosure {
                let metrics = self.metricsCache.getEndpointMetrics(
                    id: .init(endpoint: context.endpointPath ?? "Unknown", method: request.method, status: responseStatus)
                )
                metrics.counter.increment()
                metrics.timer.recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
                activeRequestMeter.decrement()
            }
            return response
        } catch {
            let errorType: HTTPResponse.Status
            if let httpError = error as? any HTTPResponseError {
                errorType = httpError.status
            } else {
                errorType = .internalServerError
            }
            let metrics = self.metricsCache.getEndpointMetrics(
                id: .init(endpoint: context.endpointPath ?? "NotFound", method: request.method, status: errorType)
            )
            metrics.counter.increment()
            metrics.errorCounter.increment()
            activeRequestMeter.decrement()
            throw error
        }
    }
}

/// Cache to store, metrics associated with particular endpoints and methods.
///
/// This should provide a quicker lookup for metrics primitives than expecting the
/// underlying metrics factory to do a general lookup
final class MetricsCache: Sendable {
    struct MethodMetrics: Sendable {
        struct ID: Hashable {
            let method: HTTPRequest.Method
        }
        let activeRequestMeter: Meter

        init(id: ID) {
            self.activeRequestMeter = Meter(label: "http.server.active_requests", dimensions: [("http.request.method", id.method.description)])
        }
    }
    struct EndpointMetrics: Sendable {
        struct ID: Hashable {
            let endpoint: String
            let method: HTTPRequest.Method
            let status: HTTPResponse.Status
        }
        let counter: Counter
        let timer: Timer
        let errorCounter: Counter

        init(id: ID) {
            self.counter = Counter(
                label: "hb.requests",
                dimensions: [
                    ("http.route", id.endpoint),
                    ("http.request.method", id.method.description),
                    ("http.response.status_code", id.status.code.description),
                ]
            )
            self.timer = Timer(
                label: "http.server.request.duration",
                dimensions: [
                    ("http.route", id.endpoint),
                    ("http.request.method", id.method.description),
                    ("http.response.status_code", id.status.code.description),
                ],
                preferredDisplayUnit: .seconds
            )
            self.errorCounter = Counter(
                label: "hb.request.errors",
                dimensions: [
                    ("http.route", id.endpoint),
                    ("http.request.method", id.method.description),
                    ("error.type", id.status.code.description),
                ]
            )
        }
    }
    let methodMetricsStorage: NIOLockedValueBox<[MethodMetrics.ID: MethodMetrics]>
    let endpointMetricsStorage: NIOLockedValueBox<[EndpointMetrics.ID: EndpointMetrics]>

    init() {
        self.methodMetricsStorage = .init([:])
        self.endpointMetricsStorage = .init([:])
    }

    func getMethodMetrics(id: MethodMetrics.ID) -> MethodMetrics {
        self.methodMetricsStorage.withLockedValue { metricsMap in
            if let metrics = metricsMap[id] {
                return metrics
            } else {
                let value = MethodMetrics(id: id)
                metricsMap[id] = value
                return value
            }
        }
    }

    func getEndpointMetrics(id: EndpointMetrics.ID) -> EndpointMetrics {
        self.endpointMetricsStorage.withLockedValue { metricsMap in
            if let metrics = metricsMap[id] {
                return metrics
            } else {
                let value = EndpointMetrics(id: id)
                metricsMap[id] = value
                return value
            }
        }
    }
}
