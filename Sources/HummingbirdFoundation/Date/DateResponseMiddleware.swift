import Hummingbird

/// Adds a "Date" header to every response from the server
public struct HBDateResponseMiddleware: HBMiddleware {
    /// Initialize HBDateResponseMiddleware
    public init() {}

    /// Add "Date" header after request has been processed
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        next.respond(to: request).map { response in
            response.headers.replaceOrAdd(name: "Date", value: request.eventLoopStorage.dateCache.currentDate)
            return response
        }
    }
}
