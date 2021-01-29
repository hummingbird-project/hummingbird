import ExtrasBase64

public struct BasicAuthentication {
    public let username: String
    public let password: String
}

extension HBRequest.Auth {
    public var basic: BasicAuthentication? {
        // check for authorization header
        guard let authorization = request.headers["Authorization"].first else { return nil }
        // check for basic prefix
        guard authorization.hasPrefix("Basic ") else { return nil }
        // extract base64 data
        let base64 = String(authorization.dropFirst("Basic ".count))
        // decode base64
        guard let data = try? base64.base64decoded() else { return nil }
        // create string from data
        let usernamePassword = String(decoding: data, as: Unicode.UTF8.self)
        // split string
        let split = usernamePassword.split(separator: ":", maxSplits: 1)
        // need two splits
        guard split.count == 2 else { return nil }
        return .init(username: String(split[0]), password: String(split[1]))
    }
}
