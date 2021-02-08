import Hummingbird

extension HBResponse {
    /// Set cookie on response
    public func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}

extension HBRequest.ResponsePatch {
    /// Set cookie on reponse patch
    ///
    /// Can be accessed via `request.response.setCookie(myCookie)`
    public func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}
