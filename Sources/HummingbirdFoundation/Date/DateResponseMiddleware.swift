import Hummingbird

public struct HBDateResponseMiddleware: HBMiddleware {
    public init() {}
    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        next.respond(to: request).map { response in
            response.headers.replaceOrAdd(name: "Date", value: request.eventLoopStorage.dateCache.currentDate)
            return response
        }
    }
}
