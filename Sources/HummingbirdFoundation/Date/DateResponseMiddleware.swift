import Hummingbird

/// Adds a "Date" header to every response from the server
public struct HBDateResponseMiddleware: HBMiddleware {
    /// Initialize HBDateResponseMiddleware
    public init(application: HBApplication) {
        // the date response middleware requires that the data cache has been setup
        application.addDateCaches()
    }

    /// Add "Date" header after request has been processed
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        next.respond(to: request).map { response in
            response.headers.add(name: "Date", value: HBDateCache.dateCache(for: request.eventLoop).currentDate)
            return response
        }
    }
}
