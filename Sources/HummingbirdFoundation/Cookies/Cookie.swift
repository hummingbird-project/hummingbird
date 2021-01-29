import Foundation

public struct HBCookie: CustomStringConvertible {
    public enum SameSite: String {
        case lax = "Lax"
        case secure = "Secure"
        case none = "None"
    }

    /// Cookie name
    let name: String
    /// Cookie value
    let value: String
    /// indicates the maximum lifetime of the cookie
    let expires: Date?
    /// indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires
    /// (not all user agents support max-age)
    let maxAge: Int?
    /// specifies those hosts to which the cookie will be sent
    let domain: String?
    /// The scope of each cookie is limited to a set of paths, controlled by the Path attribute
    let path: String?
    /// The Secure attribute limits the scope of the cookie to "secure" channels
    let secure: Bool
    /// The HttpOnly attribute limits the scope of the cookie to HTTP requests
    let httpOnly: Bool
    /// The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
    let sameSite: SameSite?

    public init(
        name: String,
        value: String,
        expires: Date? = nil,
        maxAge: Int? = nil,
        domain: String? = nil,
        path: String? = nil,
        secure: Bool,
        httpOnly: Bool,
        sameSite: SameSite? = nil
    ) {
        self.name = name
        self.value = value
        self.expires = expires
        self.maxAge = maxAge
        self.domain = domain
        self.path = path
        self.secure = secure
        self.httpOnly = httpOnly
        self.sameSite = sameSite
    }

    public var description: String {
        var output: String = "\(self.name)=\(self.value)"
        if let expires = self.expires {
            output += "; Expires=\(DateCache.rfc1123Formatter.string(from: expires))"
        }
        if let maxAge = self.maxAge { output += "; Max-Age=\(maxAge)" }
        if let domain = self.domain { output += "; Domain=\(domain)" }
        if let path = self.path { output += "; Path=\(path)" }
        if self.secure { output += "; Secure" }
        if self.httpOnly { output += "; HttpOnly" }
        if let sameSite = self.sameSite { output += "; Same-Site=\(sameSite)"}
        return output
    }
}
