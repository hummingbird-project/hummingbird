import Hummingbird

extension HBResponse {
    func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}

extension HBRequest.ResponsePatch {
    func setCookie(_ cookie: HBCookie) {
        self.headers.add(name: "Set-Cookie", value: cookie.description)
    }
}
