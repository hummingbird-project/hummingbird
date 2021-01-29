public struct BearerAuthentication {
    public let token: String
}

extension HBRequest.Auth {
    public var bearer: BearerAuthentication? {
        // check for authorization header
        guard let authorization = request.headers["Authorization"].first else { return nil }
        // check for bearer prefix
        guard authorization.hasPrefix("Bearer ") else { return nil }
        // return token
        return .init(token: String(authorization.dropFirst("Bearer ".count)))
    }
}
