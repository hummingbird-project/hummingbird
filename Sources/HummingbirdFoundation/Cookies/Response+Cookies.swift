import Hummingbird

extension HBResponse {
    struct Cookies {
        func set(cookie: HBCookie) {
            self.response.headers.add(name: "Set-Cookie", value: cookie.description)
        }

        let response: HBResponse
    }

    var cookies: Cookies { return .init(response: self) }
}

extension HBRequest.ResponsePatch {
    struct Cookies {
        func set(cookie: HBCookie) {
            self.response.headers.add(name: "Set-Cookie", value: cookie.description)
        }

        var response: HBRequest.ResponsePatch
    }

    var cookies: Cookies { return .init(response: self) }
}
