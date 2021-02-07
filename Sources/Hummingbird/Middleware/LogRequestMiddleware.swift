import Logging

/// Outputs to log for every call to server
public struct HBLogRequestsMiddleware: HBMiddleware {
    let logLevel: Logger.Level
    let includeHeaders: Bool

    public init(_ logLevel: Logger.Level, includeHeaders: Bool = false) {
        self.logLevel = logLevel
        self.includeHeaders = includeHeaders
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        if self.includeHeaders {
            request.logger.log(level: self.logLevel, "\(request.headers)")
        } else {
            request.logger.log(level: self.logLevel, "")
        }
        return next.respond(to: request)
    }
}
