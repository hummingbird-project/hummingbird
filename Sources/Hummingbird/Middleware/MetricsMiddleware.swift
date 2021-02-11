import Dispatch
import Metrics

/// Middleware recording metrics for each request
///
/// Records the number of requests, the request duration and how many errors were thrown. Each metric has additional
/// dimensions URI and method.
public struct HBMetricsMiddleware: HBMiddleware {
    public init() {}

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        let dimensions: [(String, String)] = [
            ("hb_uri", request.uri.description),
            ("hb_method", request.method.rawValue),
        ]
        let startTime = DispatchTime.now().uptimeNanoseconds

        Counter(label: "hb_requests", dimensions: dimensions).increment()

        return next.respond(to: request).map { response in
            Metrics.Timer(
                label: "hb_request_duration",
                dimensions: dimensions,
                preferredDisplayUnit: .seconds
            ).recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
            return response
        }
        .flatMapErrorThrowing { error in
            Counter(label: "hb_errors", dimensions: dimensions).increment()
            throw error
        }
    }
}
