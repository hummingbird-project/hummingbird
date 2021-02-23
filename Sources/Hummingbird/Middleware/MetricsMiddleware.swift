import Dispatch
import Metrics

/// Middleware recording metrics for each request
///
/// Records the number of requests, the request duration and how many errors were thrown. Each metric has additional
/// dimensions URI and method.
public struct HBMetricsMiddleware: HBMiddleware {
    public init() {}

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        let startTime = DispatchTime.now().uptimeNanoseconds

        return next.respond(to: request).map { response in
            // need to create dimensions once request has been responded to ensure
            // we have the correct endpoint path
            let dimensions: [(String, String)] = [
                ("hb_uri", request.endpointPath ?? request.uri.path),
                ("hb_method", request.method.rawValue),
            ]
            Counter(label: "hb_requests", dimensions: dimensions).increment()
            Metrics.Timer(
                label: "hb_request_duration",
                dimensions: dimensions,
                preferredDisplayUnit: .seconds
            ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
            return response
        }
        .flatMapErrorThrowing { error in
            // need to create dimensions once request has been responded to ensure
            // we have the correct endpoint path
            let dimensions: [(String, String)]
            if let error = error as? HBHTTPError, error.status == .notFound {
                // Don't record uri in 404 errors, to avoid spamming of metrics
                dimensions = [
                    ("hb_method", request.method.rawValue),
                ]
            } else {
                dimensions = [
                    ("hb_uri", request.endpointPath ?? request.uri.path),
                    ("hb_method", request.method.rawValue),
                ]
            }
            Counter(label: "hb_errors", dimensions: dimensions).increment()
            throw error
        }
    }
}
