import Hummingbird

extension HBResponse {
    public func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}

extension HBRequest.ResponsePatch {
    public func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}
