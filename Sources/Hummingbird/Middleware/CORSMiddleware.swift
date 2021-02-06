import NIO

public struct HBCORSMiddleware: HBMiddleware {
    public enum AllowOrigin {
        case none
        case all
        case originBased
        case custom(String)

        func value(for request: HBRequest) -> String? {
            switch self {
            case .none:
                return nil
            case .all:
                return "*"
            case .originBased:
                let origin = request.headers["origin"].first
                if origin == "null" { return nil }
                return origin
            case .custom(let value):
                return value
            }
        }
    }

    let allowOrigin: AllowOrigin
    let allowHeaders: String
    let allowMethods: String
    let allowCredentials: Bool
    let exposedHeaders: String?
    let maxAge: String?

    public init(
        allowOrigin: AllowOrigin = .originBased,
        allowHeaders: [String] = ["accept", "authorization", "content-type", "origin"],
        allowMethods: [HTTPMethod] = [.GET, .POST, .HEAD, .OPTIONS],
        allowCredentials: Bool = false,
        exposedHeaders: [String]? = nil,
        maxAge: TimeAmount? = nil
    ) {
        self.allowOrigin = allowOrigin
        self.allowHeaders = allowHeaders.joined(separator: ", ")
        self.allowMethods = allowMethods.map { $0.rawValue }.joined(separator: ", ")
        self.allowCredentials = allowCredentials
        self.exposedHeaders = exposedHeaders?.joined(separator: ", ")
        self.maxAge = maxAge.map { String(describing: $0.nanoseconds / 1_000_000_000) }
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        // if no origin header then don't apply CORS
        guard request.headers["origin"].first != nil else { return next.respond(to: request) }

        if request.method == .OPTIONS {
            // if request is OPTIONS then return CORS headers and skip the rest of the middleware chain
            var headers: HTTPHeaders = [
                "access-control-allow-origin": allowOrigin.value(for: request) ?? "",
            ]
            headers.add(name: "access-control-allow-headers", value: self.allowHeaders)
            headers.add(name: "access-control-allow-methods", value: self.allowMethods)
            if self.allowCredentials {
                headers.add(name: "access-control-allow-credentials", value: "true")
            }
            if let maxAge = self.maxAge {
                headers.add(name: "access-control-max-age", value: maxAge)
            }
            if let exposedHeaders = self.exposedHeaders {
                headers.add(name: "access-control-expose-headers", value: exposedHeaders)
            }
            if case .originBased = self.allowOrigin {
                headers.add(name: "vary", value: "Origin")
            }

            return request.success(HBResponse(status: .noContent, headers: headers, body: .empty))
        } else {
            // if not OPTIONS then run rest of middleware chain and add origin value at the end
            return next.respond(to: request).map { response in
                response.headers.replaceOrAdd(name: "access-control-allow-origin", value: self.allowOrigin.value(for: request) ?? "")
                if case .originBased = self.allowOrigin {
                    response.headers.add(name: "vary", value: "Origin")
                }
                return response
            }
        }
    }
}
